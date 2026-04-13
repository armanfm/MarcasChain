// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Interface do contrato Marcas
interface IMarcas {
    function registrar(string memory nome, address usuario) external;

    function analisar(string memory nome)
        external
        view
        returns (
            uint256,
            string memory,
            string memory
        );

    function aprovadoGovernanca(bytes32) external view returns (bool);
}

contract MarcasTempo {

    IMarcas public marcas;

    // 💰 preços
    uint256 public precoRegistro = 0.001 ether;
    uint256 public precoPorAno = 0.001 ether;

    // ⏳ tempo
    struct TempoRegistro {
        uint256 expiracao;
        uint256 anosComprados;
    }

    mapping(bytes32 => TempoRegistro) public tempos;

    // 👤 owner
    address public owner = msg.sender;

    modifier onlyOwner() {
        require(msg.sender == owner, "Nao autorizado");
        _;
    }

    // =========================
    // 🔹 CONSTRUTOR
    // =========================
    constructor(address _marcas) {
        marcas = IMarcas(_marcas);
    }

    // =========================
    // 🔥 REGISTRAR (FLUXO COMPLETO)
    // =========================
    function registrar(string memory nome, uint256 anosExtras) public payable {

        // 🔍 analisa antes de tudo
        (, string memory decision, ) = marcas.analisar(nome);

        // ❌ REJEITADO
        require(
            keccak256(bytes(decision)) != keccak256(bytes("REJECTED")),
            "Registro rejeitado"
        );

        bytes32 hash = keccak256(abi.encodePacked(nome));

        // ⚠️ GOVERNANÇA
        if (keccak256(bytes(decision)) == keccak256(bytes("GOVERNANCE"))) {
            require(
                marcas.aprovadoGovernanca(hash),
                "Aguarde aprovacao da governanca"
            );
        }

        // 💰 cálculo (1 ano obrigatório + extras)
        uint256 totalAnos = anosExtras + 1;

        uint256 custo = precoRegistro + (precoPorAno * totalAnos);
        require(msg.value >= custo, "Pagamento insuficiente");

        // 🔥 registra no contrato principal
        marcas.registrar(nome, msg.sender);

        // ⏳ salva tempo
        tempos[hash] = TempoRegistro({
            expiracao: block.timestamp + (totalAnos * 365 days),
            anosComprados: totalAnos
        });
    }

    // =========================
    // 🔹 RENOVAR
    // =========================
    function renovar(string memory nome, uint256 anos) public payable {

        require(anos > 0, "Minimo 1 ano");

        bytes32 hash = keccak256(abi.encodePacked(nome));

        require(tempos[hash].expiracao > 0, "Nao registrado");

        uint256 custo = precoPorAno * anos;
        require(msg.value >= custo, "Pagamento insuficiente");

        if (block.timestamp > tempos[hash].expiracao) {
            tempos[hash].expiracao = block.timestamp + (anos * 365 days);
        } else {
            tempos[hash].expiracao += (anos * 365 days);
        }

        tempos[hash].anosComprados += anos;
    }

    // =========================
    // 🔹 STATUS
    // =========================
    function estaAtiva(string memory nome) public view returns (bool) {
        bytes32 hash = keccak256(abi.encodePacked(nome));

        if (tempos[hash].expiracao == 0) return false;

        return block.timestamp < tempos[hash].expiracao;
    }

    function tempoRestante(string memory nome) public view returns (uint256) {
        bytes32 hash = keccak256(abi.encodePacked(nome));

        if (block.timestamp >= tempos[hash].expiracao) return 0;

        return tempos[hash].expiracao - block.timestamp;
    }

    // =========================
    // 🔹 ADMIN
    // =========================
    function alterarPrecoRegistro(uint256 novoPreco) public onlyOwner {
        precoRegistro = novoPreco;
    }

    function alterarPreco(uint256 novoPreco) public onlyOwner {
        precoPorAno = novoPreco;
    }

    function sacar() public onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
}
