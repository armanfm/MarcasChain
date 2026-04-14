// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts@4.9.3/token/ERC721/extensions/ERC721URIStorage.sol";
// 🔐 Proteção contra reentrância (ataques em funções críticas)
import "@openzeppelin/contracts@4.9.3/security/ReentrancyGuard.sol";

// Interface mínima do Marcas.sol
interface IMarcas {
    function registros(bytes32 hash) external view returns (
        string memory nome,
        address dono,
        uint256 timestamp,
        uint256 score,
        bool veioDaGovernanca
    );
    function liberarMarca(string memory nome) external;
}

contract MarcasNFT is ERC721, ReentrancyGuard {

    IMarcas public marcas;

    uint256 public precoMint;
    uint256 public precoRenovacao;
    uint256 public duracaoProtecao = 10 * 365 days; // 10 anos
    uint256 public prazoMint       = 1 days;         // janela para mintar após registro

    address public owner;
    uint256 private _nextTokenId;

    struct MarcaNFT {
        string  nome;
        uint256 expiracao;
        uint256 mintedAt;
    }

    // keccak256(abi.encode(nome)) → tokenId
    mapping(bytes32 => uint256) public hashParaToken;

    // tokenId → dados
    mapping(uint256 => MarcaNFT) public tokens;

    // hash → tem token ativo
    mapping(bytes32 => bool) public temTokenAtivo;

    event MarcaMintada(string indexed nome, address indexed dono, uint256 tokenId, uint256 expiracao);
    event MarcaRenovada(string indexed nome, address indexed dono, uint256 novaExpiracao);
    event MarcaLiberada(string indexed nome, uint256 tokenId, address liberadoPor);

    modifier onlyOwner() {
        require(msg.sender == owner, "Nao autorizado");
        _;
    }

    // _precoMint e _precoRenovacao em wei
    // Ex: 1000000000000000 = 0.001 ETH
    constructor(
        address _marcas,
        uint256 _precoMint,
        uint256 _precoRenovacao
    ) ERC721("MarcasChain NFT", "MCNFT") {
        require(_marcas != address(0), "Endereco invalido");
        marcas         = IMarcas(_marcas);
        owner          = msg.sender;
        precoMint      = _precoMint;
        precoRenovacao = _precoRenovacao;
    }

    // ══════════════════════════════════════════
    // 🔹 MINT
    // Usuário registrou a marca no Marcas.sol e tem até 24h para mintar
    // ══════════════════════════════════════════
    function mint(string memory nome) external payable nonReentrant {
        require(msg.value >= precoMint, "Pagamento insuficiente");

        bytes32 hash = keccak256(abi.encode(nome));

        // Verifica registro no Marcas.sol
        (, address dono, uint256 registradoEm, , ) = marcas.registros(hash);
        require(dono != address(0), "Marca nao registrada no Marcas");

        // Calcula status inline (sem chamar statusMarca para evitar referencia circular)
        bool dentroDosPrazo = block.timestamp <= registradoEm + prazoMint;
        bool temNFTExpirado = temTokenAtivo[hash] &&
            block.timestamp > tokens[hashParaToken[hash]].expiracao;

        if (dentroDosPrazo && !temTokenAtivo[hash]) {
            // RESERVADA: dentro das 24h, so o dono pode mintar
            require(dono == msg.sender, "Apenas o dono pode mintar neste prazo");
        } else if (!dentroDosPrazo || temNFTExpirado) {
            // EXPIRADA: prazo vencido ou NFT expirou, qualquer um pode mintar
            // Limpa NFT expirado se existir
            if (temTokenAtivo[hash]) {
                uint256 oldToken = hashParaToken[hash];
                _burn(oldToken);
                delete tokens[oldToken];
                temTokenAtivo[hash] = false;
                delete hashParaToken[hash];
            }
        } else {
            revert("Marca ja tem NFT ativo");
        }

        // Mint
        uint256 tokenId = _nextTokenId++;
        _safeMint(msg.sender, tokenId);

        uint256 expiracao = block.timestamp + duracaoProtecao;

        tokens[tokenId] = MarcaNFT({
            nome:      nome,
            expiracao: expiracao,
            mintedAt:  block.timestamp
        });

        hashParaToken[hash] = tokenId;
        temTokenAtivo[hash] = true;

        // Troco
        if (msg.value > precoMint) {
            (bool ok, ) = msg.sender.call{value: msg.value - precoMint}("");
            require(ok, "Falha troco");
        }

        // Pagamento ao owner
        (bool sent, ) = owner.call{value: precoMint}("");
        require(sent, "Falha pagamento");

        emit MarcaMintada(nome, msg.sender, tokenId, expiracao);
    }

    // ══════════════════════════════════════════
    // 🔹 RENOVAR — estende 10 anos
    // ══════════════════════════════════════════
    function renovar(string memory nome) external payable nonReentrant {
        require(msg.value >= precoRenovacao, "Pagamento insuficiente");

        bytes32 hash = keccak256(abi.encode(nome));
        require(temTokenAtivo[hash], "Sem NFT ativo para esta marca");

        uint256 tokenId = hashParaToken[hash];
        require(ownerOf(tokenId) == msg.sender, "Voce nao e o dono do NFT");

        MarcaNFT storage nft = tokens[tokenId];

        // Estende a partir da expiração atual ou de agora se já expirou
        uint256 base = nft.expiracao > block.timestamp
            ? nft.expiracao
            : block.timestamp;

        nft.expiracao = base + duracaoProtecao;

        // Troco
        if (msg.value > precoRenovacao) {
            (bool ok, ) = msg.sender.call{value: msg.value - precoRenovacao}("");
            require(ok, "Falha troco");
        }

        (bool sent, ) = owner.call{value: precoRenovacao}("");
        require(sent, "Falha pagamento");

        emit MarcaRenovada(nome, msg.sender, nft.expiracao);
    }

    // ══════════════════════════════════════════
    // 🔹 LIBERAR — qualquer um pode liberar marca expirada
    // Burn do NFT + avisa Marcas.sol para liberar o registro
    // ══════════════════════════════════════════
    function liberar(string memory nome) external nonReentrant {
        bytes32 hash = keccak256(abi.encode(nome));
        require(temTokenAtivo[hash], "Sem NFT ativo");

        uint256 tokenId = hashParaToken[hash];
        require(
            block.timestamp > tokens[tokenId].expiracao,
            "NFT ainda vigente"
        );

        // Burn
        _burn(tokenId);

        // Limpa estado
        temTokenAtivo[hash] = false;
        delete hashParaToken[hash];
        delete tokens[tokenId];

        // Avisa Marcas.sol
        marcas.liberarMarca(nome);

        emit MarcaLiberada(nome, tokenId, msg.sender);
    }

    // ══════════════════════════════════════════
    // 🔹 CONSULTAS
    // ══════════════════════════════════════════

    // DISPONIVEL | RESERVADA | ATIVA
    // EXPIRADA nao existe como status — prazo vencido = DISPONIVEL
    function statusMarca(string memory nome) public view returns (string memory) {
        bytes32 hash = keccak256(abi.encode(nome));

        // Tem NFT mintado e vigente?
        if (temTokenAtivo[hash]) {
            uint256 tokenId = hashParaToken[hash];
            if (block.timestamp <= tokens[tokenId].expiracao) {
                return "ATIVA";
            }
            // NFT expirou mas ainda nao liberado — tratar como DISPONIVEL
            return "DISPONIVEL";
        }

        // Registrada no Marcas.sol e dentro do prazo de 24h?
        (, address dono, uint256 registradoEm, , ) = marcas.registros(hash);
        if (dono != address(0) && block.timestamp <= registradoEm + prazoMint) {
            return "RESERVADA";
        }

        // Tudo mais = DISPONIVEL
        return "DISPONIVEL";
    }

    function estaAtiva(string memory nome) public view returns (bool) {
        bytes32 hash = keccak256(abi.encode(nome));
        if (!temTokenAtivo[hash]) return false;
        return block.timestamp <= tokens[hashParaToken[hash]].expiracao;
    }

    function getExpiracao(string memory nome) public view returns (uint256) {
        bytes32 hash = keccak256(abi.encode(nome));
        if (!temTokenAtivo[hash]) return 0;
        return tokens[hashParaToken[hash]].expiracao;
    }

    function tempoRestante(string memory nome) public view returns (uint256) {
        bytes32 hash = keccak256(abi.encode(nome));
        if (!temTokenAtivo[hash]) return 0;
        uint256 exp = tokens[hashParaToken[hash]].expiracao;
        if (block.timestamp >= exp) return 0;
        return exp - block.timestamp;
    }

    function getTokenPorNome(string memory nome) public view returns (
        uint256 tokenId,
        address dono,
        uint256 expiracao,
        uint256 mintedAt,
        string memory status
    ) {
        bytes32 hash = keccak256(abi.encode(nome));
        require(temTokenAtivo[hash], "Sem NFT para esta marca");
        tokenId  = hashParaToken[hash];
        dono     = ownerOf(tokenId);
        expiracao = tokens[tokenId].expiracao;
        mintedAt  = tokens[tokenId].mintedAt;
        status    = statusMarca(nome);
    }

    // ══════════════════════════════════════════
    // 🔹 ADMIN
    // ══════════════════════════════════════════
    function alterarPrecoMint(uint256 novoPreco) external onlyOwner {
        precoMint = novoPreco;
    }

    function alterarPrecoRenovacao(uint256 novoPreco) external onlyOwner {
        precoRenovacao = novoPreco;
    }

    function alterarPrazoMint(uint256 novoPrazo) external onlyOwner {
        require(novoPrazo >= 1 hours, "Minimo 1 hora");
        prazoMint = novoPrazo;
    }

    function alterarDuracaoProtecao(uint256 novaDuracao) external onlyOwner {
        require(novaDuracao >= 365 days, "Minimo 1 ano");
        duracaoProtecao = novaDuracao;
    }

    function sacar() external onlyOwner nonReentrant {
        uint256 saldo = address(this).balance;
        require(saldo > 0, "Sem saldo");
        (bool ok, ) = owner.call{value: saldo}("");
        require(ok, "Falha saque");
    }

    receive() external payable {
        revert("Use mint() ou renovar()");
    }
}
