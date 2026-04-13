// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Interface do contrato Marcas - CORRIGIDA
interface IMarcas {
    function registrar(string memory nome, address usuario) external;
    function analisar(string memory nome) external view returns (uint256, string memory, string memory);
    function aprovadoGovernanca(bytes32) external view returns (bool);
    function aprovarGovernanca(string memory nome) external; // 🔥 CORRETO
}

contract MarcasTempo {

    IMarcas public marcas;
    
    uint256 public precoRegistro = 0.001 ether;
    uint256 public precoPorAno = 0.001 ether;
    
    struct TempoRegistro {
        uint256 expiracao;
        uint256 anosComprados;
        bool aguardandoGovernanca;
    }
    
    mapping(bytes32 => TempoRegistro) public tempos;
    mapping(address => bytes32[]) public solicitacoesUsuario;
    
    address public owner;
    
    // Eventos
    event AnaliseSolicitada(string indexed nome, address indexed usuario, uint256 score, string decision);
    event AguardandoGovernanca(string indexed nome, address indexed usuario);
    event AprovadoParaRegistro(string indexed nome, address indexed usuario, uint256 custo);
    event RejeitadoPeloGoverno(string indexed nome, address indexed usuario);
    event RegistroConfirmado(string indexed nome, address indexed usuario, uint256 expiracao);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Nao autorizado");
        _;
    }
    
    constructor(address _marcas) {
        marcas = IMarcas(_marcas);
        owner = msg.sender;
    }
    
    // =========================
    // 🔹 PASSO 1: SOLICITAR ANÁLISE (GRÁTIS)
    // =========================
    function solicitarAnalise(string memory nome) public {
        bytes32 hash = keccak256(abi.encodePacked(nome));
        
        require(tempos[hash].expiracao == 0, "Marca ja registrada");
        
        (uint256 score, string memory decision, ) = marcas.analisar(nome);
        
        emit AnaliseSolicitada(nome, msg.sender, score, decision);
        
        // REJECTED
        if (keccak256(bytes(decision)) == keccak256(bytes("REJECTED"))) {
            revert("Marca REJEITADA automaticamente");
        }
        
        // GOVERNANCE
        if (keccak256(bytes(decision)) == keccak256(bytes("GOVERNANCE"))) {
            tempos[hash].aguardandoGovernanca = true;
            solicitacoesUsuario[msg.sender].push(hash);
            emit AguardandoGovernanca(nome, msg.sender);
            revert("Aguardando aprovacao da governanca");
        }
        
        // APPROVED
        emit AprovadoParaRegistro(nome, msg.sender, calcularCusto(1));
    }
    
    // =========================
    // 🔹 PASSO 2: GOVERNANÇA APROVA (SÓ OWNER)
    // =========================
    function aprovarPeloGoverno(string memory nome, address usuario) public onlyOwner {
        bytes32 hash = keccak256(abi.encodePacked(nome));
        
        require(tempos[hash].aguardandoGovernanca, "Nao aguardando aprovacao");
        require(tempos[hash].expiracao == 0, "Marca ja registrada");
        
        // 🔥 Agora funciona! Chama a função correta
        marcas.aprovarGovernanca(nome);
        
        tempos[hash].aguardandoGovernanca = false;
        
        emit AprovadoParaRegistro(nome, usuario, calcularCusto(1));
    }
    
    // =========================
    // 🔹 PASSO 3: GOVERNANÇA REJEITA (SÓ OWNER)
    // =========================
    function rejeitarPeloGoverno(string memory nome, address usuario) public onlyOwner {
        bytes32 hash = keccak256(abi.encodePacked(nome));
        
        require(tempos[hash].aguardandoGovernanca, "Nao aguardando aprovacao");
        
        delete tempos[hash];
        emit RejeitadoPeloGoverno(nome, usuario);
    }
    
    // =========================
    // 🔹 PASSO 4: PAGAR E REGISTRAR
    // =========================
    function pagarERegistrar(string memory nome, uint256 anosExtras) public payable {
        bytes32 hash = keccak256(abi.encodePacked(nome));
        
        require(!tempos[hash].aguardandoGovernanca, "Aguardando aprovacao da governanca");
        require(tempos[hash].expiracao == 0, "Marca ja registrada ou aprovacao expirada");
        
        ( , string memory decision, ) = marcas.analisar(nome);
        
        bool precisaGovernanca = keccak256(bytes(decision)) == keccak256(bytes("GOVERNANCE"));
        
        if (precisaGovernanca) {
            require(marcas.aprovadoGovernanca(hash), "Governanca ainda nao aprovou");
        }
        
        uint256 totalAnos = anosExtras + 1;
        uint256 custo = precoRegistro + (precoPorAno * totalAnos);
        require(msg.value >= custo, "Pagamento insuficiente");
        
        marcas.registrar(nome, msg.sender);
        
        tempos[hash] = TempoRegistro({
            expiracao: block.timestamp + (totalAnos * 365 days),
            anosComprados: totalAnos,
            aguardandoGovernanca: false
        });
        
        emit RegistroConfirmado(nome, msg.sender, tempos[hash].expiracao);
        
        if (msg.value > custo) {
            payable(msg.sender).transfer(msg.value - custo);
        }
    }
    
    // =========================
    // 🔹 FUNÇÕES AUXILIARES
    // =========================
    function calcularCusto(uint256 anos) public view returns (uint256) {
        return precoRegistro + (precoPorAno * anos);
    }
    
    function estaAtiva(string memory nome) public view returns (bool) {
        bytes32 hash = keccak256(abi.encodePacked(nome));
        if (tempos[hash].expiracao == 0) return false;
        return block.timestamp < tempos[hash].expiracao;
    }
    
    function renovar(string memory nome, uint256 anos) public payable {
        bytes32 hash = keccak256(abi.encodePacked(nome));
        require(tempos[hash].expiracao > 0, "Nao registrado");
        require(!tempos[hash].aguardandoGovernanca, "Aguardando governanca");
        
        uint256 custo = precoPorAno * anos;
        require(msg.value >= custo, "Pagamento insuficiente");
        
        if (block.timestamp > tempos[hash].expiracao) {
            tempos[hash].expiracao = block.timestamp + (anos * 365 days);
        } else {
            tempos[hash].expiracao += (anos * 365 days);
        }
        
        tempos[hash].anosComprados += anos;
    }
    
    function sacar() public onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
    
    function alterarPrecoRegistro(uint256 novoPreco) public onlyOwner {
        precoRegistro = novoPreco;
    }
    
    function alterarPrecoPorAno(uint256 novoPreco) public onlyOwner {
        precoPorAno = novoPreco;
    }
}
