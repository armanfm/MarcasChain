// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts@4.9.6/security/ReentrancyGuard.sol";

interface IMarcas {
    function registros(bytes32 hash) external view returns (
        string memory nome,
        address dono,
        uint256 timestamp,
        uint256 score,
        bool veioDaGovernanca
    );

    function isValidFormat(string memory nome) external view returns (bool);
}

contract MarcasTempo is ReentrancyGuard {

    IMarcas public marcas;
    
    uint256 public precoPorAno = 0.001 ether;
    uint256 public duracaoBase = 365 days;
    
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
    // 🔹 LÓGICA INTERNA
    // =========================
    function _pagarTempo(string memory nome, uint256 anos, bool isRenovacao)
        internal
        returns (uint256)
    {
        require(anos > 0, "Anos deve ser maior que zero");

        require(marcas.isValidFormat(nome), "Formato invalido");

        bytes32 hash = keccak256(bytes(nome));

        ( , address dono, , , ) = marcas.registros(hash);

        require(dono != address(0), "Marca nao registrada");
        require(dono == msg.sender, "Nao e dono");

        uint256 custo = precoPorAno * anos;
        require(msg.value >= custo, "Pagamento insuficiente");

        uint256 novaExpiracao;

        if (tempos[hash].ativo && block.timestamp < tempos[hash].expiracao) {
            novaExpiracao = tempos[hash].expiracao + (anos * duracaoBase);
        } else {
            novaExpiracao = block.timestamp + (anos * duracaoBase);

            if (tempos[hash].expiracao == 0) {
                registrosUsuario[msg.sender].push(hash);
                hashParaNome[hash] = nome;
            }
        }

        tempos[hash] = TempoRegistro({
            expiracao: novaExpiracao,
            ultimaRenovacao: block.timestamp,
            totalPago: tempos[hash].totalPago + custo,
            ativo: true
        });

        if (msg.value > custo) {
            uint256 troco = msg.value - custo;
            (bool ok, ) = msg.sender.call{value: troco}("");
            require(ok, "Falha troco");
            emit TrocoDevolvido(msg.sender, troco);
        }

        if (!isRenovacao) {
            emit TempoPago(nome, msg.sender, novaExpiracao, custo);
        }

        return novaExpiracao;
    }

    // =========================
    // 🔹 FUNÇÕES PÚBLICAS
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
        uint256 nova = _pagarTempo(nome, anos, true);
        emit Renovacao(nome, msg.sender, nova, msg.value);
    }

    // =========================
    // 🔹 CONSULTAS
    // =========================
    function estaAtiva(string memory nome) public view returns (bool) {
        require(marcas.isValidFormat(nome), "Formato invalido");

        bytes32 hash = keccak256(bytes(nome));

        return tempos[hash].ativo && block.timestamp < tempos[hash].expiracao;
    }

    function tempoRestante(string memory nome) public view returns (uint256) {
        require(marcas.isValidFormat(nome), "Formato invalido");

        bytes32 hash = keccak256(bytes(nome));

        if (!tempos[hash].ativo || block.timestamp >= tempos[hash].expiracao) {
            return 0;
        }

        return tempos[hash].expiracao - block.timestamp;
    }

    function getExpiracao(string memory nome) public view returns (uint256) {
        require(marcas.isValidFormat(nome), "Formato invalido");

        bytes32 hash = keccak256(bytes(nome));

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
    // 🔹 OWNER
    // =========================
    function sacar() public onlyOwner nonReentrant {
        uint256 saldo = address(this).balance;
        require(saldo > 0, "Sem saldo");

        (bool ok, ) = owner.call{value: saldo}("");
        require(ok, "Falha saque");
    }

    function alterarPrecoPorAno(uint256 novoPreco) public onlyOwner {
        require(novoPreco > 0, "Preco invalido");
        precoPorAno = novoPreco;
    }

    function alterarDuracaoBase(uint256 novaDuracao) public onlyOwner {
        require(novaDuracao >= 30 days, "Minimo 30 dias");
        duracaoBase = novaDuracao;
    }

    // =========================
    // 🔹 LIMPEZA
    // =========================
    function limparExpirados(bytes32[] memory hashes) public {
        for (uint i = 0; i < hashes.length; i++) {
            bytes32 hash = hashes[i];

            if (tempos[hash].ativo && block.timestamp >= tempos[hash].expiracao) {
                tempos[hash].ativo = false;

                string memory nome = hashParaNome[hash];
                address dono;

                (, address donoMarca, , , ) = marcas.registros(hash);
                if (donoMarca != address(0)) {
                    dono = donoMarca;
                }

                emit RegistroExpirado(nome, dono);
            }
        }
    }

    // =========================
    // 🔹 SINCRONIZAÇÃO
    // =========================
    function sincronizarDono(string memory nome, address novoDono) public nonReentrant {
        require(marcas.isValidFormat(nome), "Formato invalido");

        bytes32 hash = keccak256(bytes(nome));

        (, address donoAtual, , , ) = marcas.registros(hash);

        require(donoAtual != address(0), "Nao existe");
        require(msg.sender == donoAtual, "Nao autorizado");
        require(tempos[hash].ativo, "Tempo inativo");

        bytes32[] storage lista = registrosUsuario[msg.sender];

        for (uint i = 0; i < lista.length; i++) {
            if (lista[i] == hash) {
                lista[i] = lista[lista.length - 1];
                lista.pop();
                break;
            }
        }

        registrosUsuario[novoDono].push(hash);
    }

    receive() external payable {
        revert("Use pagarTempo ou renovar");
    }
}
