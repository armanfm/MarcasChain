// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts@4.9.6/security/ReentrancyGuard.sol";

// Interface do contrato Marcas - MÍNIMO necessária
interface IMarcas {
    function registros(bytes32 hash) external view returns (
        string memory nome,
        address dono,
        uint256 timestamp,
        uint256 score,
        bool veioDaGovernanca
    );
}

contract MarcasTempo is ReentrancyGuard {

    IMarcas public marcas;
    
    uint256 public precoPorAno = 0.001 ether;
    uint256 public duracaoBase = 365 days; // 1 ano por padrão
    
    struct TempoRegistro {
        uint256 expiracao;
        uint256 ultimaRenovacao;
        uint256 totalPago;
        bool ativo;
    }
    
    mapping(bytes32 => TempoRegistro) public tempos;
    mapping(address => bytes32[]) public registrosUsuario;
    mapping(bytes32 => string) public hashParaNome;
    
    address public owner;
    
    // Eventos
    event TempoPago(string indexed nome, address indexed dono, uint256 expiracao, uint256 valorPago);
    event Renovacao(string indexed nome, address indexed dono, uint256 novaExpiracao, uint256 valorPago);
    event RegistroExpirado(string indexed nome, address indexed dono);
    event TrocoDevolvido(address indexed usuario, uint256 valor);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Nao autorizado");
        _;
    }
    
    constructor(address _marcas) {
        marcas = IMarcas(_marcas);
        owner = msg.sender;
    }
    
    // =========================
    // 🔹 LÓGICA INTERNA (sem nonReentrant)
    // =========================
    function _pagarTempo(string memory nome, uint256 anos, bool isRenovacao) 
        internal 
        returns (uint256)
    {
        require(anos > 0, "Anos deve ser maior que zero");
        
        bytes32 hash = keccak256(abi.encode(nome));
        
        // Verifica se a marca existe no Marcas
        ( , address dono, , , ) = marcas.registros(hash);
        require(dono != address(0), "Marca nao registrada no Marcas");
        require(dono == msg.sender, "Voce nao e o dono da marca");
        
        // Calcula custo
        uint256 custo = precoPorAno * anos;
        require(msg.value >= custo, "Pagamento insuficiente");
        
        uint256 novaExpiracao;
        
        // Se já existe e não expirou, estende
        if (tempos[hash].ativo && block.timestamp < tempos[hash].expiracao) {
            novaExpiracao = tempos[hash].expiracao + (anos * duracaoBase);
        } else {
            // Primeiro registro ou já expirou
            novaExpiracao = block.timestamp + (anos * duracaoBase);
            
            // Se é primeira vez, adiciona à lista do usuário
            if (tempos[hash].expiracao == 0) {
                registrosUsuario[msg.sender].push(hash);
                hashParaNome[hash] = nome;
            }
        }
        
        tempos[hash] = TempoRegistro({
            expiracao: novaExpiracao,
            ultimaRenovacao: block.timestamp,
            totalPago: tempos[hash].totalPago + custo, // CORRIGIDO: usa custo, não msg.value
            ativo: true
        });
        
        // Devolve troco
        if (msg.value > custo) {
            uint256 troco = msg.value - custo;
            (bool ok, ) = msg.sender.call{value: troco}("");
            require(ok, "Falha ao devolver troco");
            emit TrocoDevolvido(msg.sender, troco);
        }
        
        if (!isRenovacao) {
            emit TempoPago(nome, msg.sender, novaExpiracao, msg.value);
        }
        
        return novaExpiracao;
    }
    
    // =========================
    // 🔹 FUNÇÕES PÚBLICAS (com nonReentrant)
    // =========================
    
    function pagarTempo(string memory nome, uint256 anos) 
        public 
        payable 
        nonReentrant
    {
        _pagarTempo(nome, anos, false);
    }
    
    function renovar(string memory nome, uint256 anos) 
        public 
        payable 
        nonReentrant
    {
        uint256 novaExpiracao = _pagarTempo(nome, anos, true);
        emit Renovacao(nome, msg.sender, novaExpiracao, msg.value);
    }
    
    // =========================
    // 🔹 FUNÇÕES DE CONSULTA (sem proteção - só leitura)
    // =========================
    
    function estaAtiva(string memory nome) public view returns (bool) {
        bytes32 hash = keccak256(abi.encode(nome));
        return tempos[hash].ativo && block.timestamp < tempos[hash].expiracao;
    }
    
    function tempoRestante(string memory nome) public view returns (uint256) {
        bytes32 hash = keccak256(abi.encode(nome));
        if (!tempos[hash].ativo || block.timestamp >= tempos[hash].expiracao) {
            return 0;
        }
        return tempos[hash].expiracao - block.timestamp;
    }
    
    function getExpiracao(string memory nome) public view returns (uint256) {
        bytes32 hash = keccak256(abi.encode(nome));
        return tempos[hash].expiracao;
    }
    
    function getRegistrosDoUsuario(address usuario) public view returns (bytes32[] memory) {
        return registrosUsuario[usuario];
    }
    
    function getNomeDoHash(bytes32 hash) public view returns (string memory) {
        return hashParaNome[hash];
    }
    
    function calcularCusto(uint256 anos) public view returns (uint256) {
        return precoPorAno * anos;
    }
    
    // =========================
    // 🔹 FUNÇÕES DO OWNER (com proteção)
    // =========================
    
    function sacar() public onlyOwner nonReentrant {
        uint256 saldo = address(this).balance;
        require(saldo > 0, "Sem saldo");
        
        (bool ok, ) = owner.call{value: saldo}("");
        require(ok, "Falha ao sacar");
    }
    
    function alterarPrecoPorAno(uint256 novoPreco) public onlyOwner {
        require(novoPreco > 0, "Preco deve ser maior que zero");
        precoPorAno = novoPreco;
    }
    
    function alterarDuracaoBase(uint256 novaDuracao) public onlyOwner {
        require(novaDuracao >= 30 days, "Duracao minima de 30 dias");
        duracaoBase = novaDuracao;
    }
    
    // =========================
    // 🔹 LIMPEZA DE REGISTROS EXPIRADOS
    // =========================
    
    function limparExpirados(bytes32[] memory hashes) public {
        for (uint i = 0; i < hashes.length; i++) {
            bytes32 hash = hashes[i];
            if (tempos[hash].ativo && block.timestamp >= tempos[hash].expiracao) {
                tempos[hash].ativo = false;
                
                string memory nome = hashParaNome[hash];
                address dono = address(0);
                
                ( , address donoMarca, , , ) = marcas.registros(hash);
                if (donoMarca != address(0)) {
                    dono = donoMarca;
                }
                
                emit RegistroExpirado(nome, dono);
            }
        }
    }
    
    // =========================
    // 🔹 FUNÇÃO PARA TRANSFERIR REGISTRO
    // =========================
    
    function sincronizarDono(string memory nome, address novoDono) public nonReentrant {
        bytes32 hash = keccak256(abi.encode(nome));
        ( , address donoAtualMarca, , , ) = marcas.registros(hash);
        
        require(donoAtualMarca != address(0), "Marca nao existe");
        require(msg.sender == donoAtualMarca, "Apenas o dono atual pode sincronizar");
        require(tempos[hash].ativo, "Tempo nao ativo");
        
        // Remove da lista antiga
        address donoAntigo = msg.sender;
        bytes32[] storage registrosAntigos = registrosUsuario[donoAntigo];
        for (uint i = 0; i < registrosAntigos.length; i++) {
            if (registrosAntigos[i] == hash) {
                registrosAntigos[i] = registrosAntigos[registrosAntigos.length - 1];
                registrosAntigos.pop();
                break;
            }
        }
        
        // Adiciona na nova lista
        registrosUsuario[novoDono].push(hash);
    }
    
    // =========================
    // 🔹 FALLBACK
    // =========================
    
    receive() external payable {
        revert("Use pagarTempo() ou renovar()");
    }
}
