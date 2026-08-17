// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * Marcas — registro de marcas com triagem delegada ao Chainlink CRE.
 *
 * Fluxo:
 *   1. Usuario chama solicitarRegistro(nome)   -> enfileira, custo fixo
 *   2. CRE chama getNextPendingRequest()       -> view, gratis
 *   3. CRE chama analisarParaCRE(nome)         -> view, gratis
 *   4. CRE devolve o veredito via onReport()   -> unica escrita
 *
 * O loop contra a base inteira continua existindo em analisar(), mas so roda
 * em eth_call. Nenhuma funcao que escreve estado o invoca.
 *
 * Nao ha camada NFT: o proprio registro on-chain e a prova, e so entra aqui
 * o que passou pela triagem.
 */
contract Marcas {

    // ---------------------------------------------------------------
    // Tipos
    // ---------------------------------------------------------------

    struct Registro {
        string nome;
        address dono;
        uint256 timestamp;
        uint256 score;
    }

    struct Resultado {
        string nome;
        uint256 score;
    }

    enum StatusSolicitacao {
        NENHUMA,     // 0
        PENDENTE,    // 1
        APROVADA,    // 2
        REJEITADA,   // 3
        INVALIDA     // 4 - duplicada ou destravada manualmente
    }

    struct Solicitacao {
        string nome;
        address solicitante;
        uint256 criadaEm;
        uint256 processadaEm;
        uint256 score;
        bytes32 matchHash;
        uint32 algorithmVersion;
        StatusSolicitacao status;
    }

    // ---------------------------------------------------------------
    // Estado
    // ---------------------------------------------------------------

    mapping(bytes32 => Registro) public registros;
    string[] public listaMarcas;

    Solicitacao[] public solicitacoes;
    uint256 public proximaPendente;
    mapping(bytes32 => bool) public temSolicitacaoAberta;

    address public owner;
    address public creForwarder;

    uint256 public constant LIMITE_REJEICAO = 70;
    uint256 public constant MAX_NOME_BYTES = 96;

    uint8 public constant ACAO_RESULTADO_ANALISE = 1;

    // ---------------------------------------------------------------
    // Eventos
    // ---------------------------------------------------------------

    event RegistroSolicitado(uint256 indexed requestId, string nome, address indexed solicitante);
    event SolicitacaoProcessada(uint256 indexed requestId, StatusSolicitacao status, uint256 score, bytes32 matchHash);
    event MarcaRegistrada(string indexed nome, address indexed dono, uint256 score);
    event MarcaTransferida(string indexed nome, address indexed de, address indexed para);
    event CreForwarderAtualizado(address indexed anterior, address indexed novo);

    // ---------------------------------------------------------------
    // Acesso
    // ---------------------------------------------------------------

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Nao autorizado");
        _;
    }

    modifier onlyCRE() {
        require(creForwarder != address(0), "CRE forwarder nao configurado");
        require(msg.sender == creForwarder, "Apenas o CRE");
        _;
    }

    function setCreForwarder(address _forwarder) external onlyOwner {
        require(_forwarder != address(0), "Endereco invalido");
        emit CreForwarderAtualizado(creForwarder, _forwarder);
        creForwarder = _forwarder;
    }

    // ---------------------------------------------------------------
    // Fila de solicitacoes
    // ---------------------------------------------------------------

    /**
     * Entrada publica. Nao roda analise: apenas enfileira.
     * Custo praticamente fixo, independente do tamanho da base.
     */
    function solicitarRegistro(string memory nome) external returns (uint256 requestId) {
        bytes memory b = bytes(nome);
        require(b.length > 0, "Nome vazio");
        require(b.length <= MAX_NOME_BYTES, "Nome muito longo");

        bytes32 hash = keccak256(abi.encode(nome));
        require(registros[hash].timestamp == 0, "Marca ja registrada");
        require(!temSolicitacaoAberta[hash], "Ja existe solicitacao pendente");

        requestId = solicitacoes.length;

        solicitacoes.push(Solicitacao({
            nome: nome,
            solicitante: msg.sender,
            criadaEm: block.timestamp,
            processadaEm: 0,
            score: 0,
            matchHash: bytes32(0),
            algorithmVersion: 0,
            status: StatusSolicitacao.PENDENTE
        }));

        temSolicitacaoAberta[hash] = true;
        emit RegistroSolicitado(requestId, nome, msg.sender);
    }

    /**
     * Assinatura casa com NEXT_PENDING_REQUEST_ABI do workflow.
     */
    function getNextPendingRequest() external view returns (
        bool found,
        uint256 requestId,
        string memory nome
    ) {
        for (uint256 i = proximaPendente; i < solicitacoes.length; i++) {
            if (solicitacoes[i].status == StatusSolicitacao.PENDENTE) {
                return (true, i, solicitacoes[i].nome);
            }
        }
        return (false, 0, "");
    }

    function totalSolicitacoes() external view returns (uint256) {
        return solicitacoes.length;
    }

    function getSolicitacao(uint256 requestId) external view returns (Solicitacao memory) {
        require(requestId < solicitacoes.length, "requestId inexistente");
        return solicitacoes[requestId];
    }

    // ---------------------------------------------------------------
    // Recepcao do report do CRE
    // ---------------------------------------------------------------

    /**
     * Layout de report esperado (casa com o workflow):
     *   byte 0        -> acao (0x01)
     *   bytes 1..end  -> abi.encode(uint256 requestId, uint16 score,
     *                               bytes32 matchHash, uint32 algorithmVersion)
     */
    function onReport(bytes calldata /* metadata */, bytes calldata report) external onlyCRE {
        require(report.length > 1, "Report vazio");
        require(uint8(report[0]) == ACAO_RESULTADO_ANALISE, "Acao desconhecida");

        (
            uint256 requestId,
            uint16 score,
            bytes32 matchHash,
            uint32 algorithmVersion
        ) = abi.decode(report[1:], (uint256, uint16, bytes32, uint32));

        _processarResultado(requestId, score, matchHash, algorithmVersion);
    }

    function _processarResultado(
        uint256 requestId,
        uint16 score,
        bytes32 matchHash,
        uint32 algorithmVersion
    ) internal {
        require(requestId < solicitacoes.length, "requestId inexistente");

        Solicitacao storage sol = solicitacoes[requestId];
        require(sol.status == StatusSolicitacao.PENDENTE, "Solicitacao ja processada");
        require(score <= 100, "Score fora de faixa");

        sol.score = score;
        sol.matchHash = matchHash;
        sol.algorithmVersion = algorithmVersion;
        sol.processadaEm = block.timestamp;

        bytes32 hash = keccak256(abi.encode(sol.nome));
        temSolicitacaoAberta[hash] = false;

        // Corrida: alguem pode ter registrado o mesmo nome enquanto o CRE
        // analisava. Sem esta checagem daria para gravar duplicata.
        if (registros[hash].timestamp != 0) {
            sol.status = StatusSolicitacao.INVALIDA;
            _avancarCursor();
            emit SolicitacaoProcessada(requestId, StatusSolicitacao.INVALIDA, score, matchHash);
            return;
        }

        if (score >= LIMITE_REJEICAO) {
            sol.status = StatusSolicitacao.REJEITADA;
            _avancarCursor();
            emit SolicitacaoProcessada(requestId, StatusSolicitacao.REJEITADA, score, matchHash);
            return;
        }

        registros[hash] = Registro({
            nome: sol.nome,
            dono: sol.solicitante,
            timestamp: block.timestamp,
            score: score
        });
        listaMarcas.push(sol.nome);

        sol.status = StatusSolicitacao.APROVADA;
        _avancarCursor();

        emit SolicitacaoProcessada(requestId, StatusSolicitacao.APROVADA, score, matchHash);
        emit MarcaRegistrada(sol.nome, sol.solicitante, score);
    }

    function _avancarCursor() internal {
        uint256 i = proximaPendente;
        while (i < solicitacoes.length && solicitacoes[i].status != StatusSolicitacao.PENDENTE) {
            i++;
        }
        proximaPendente = i;
    }

    /**
     * Escape hatch. Se uma solicitacao travar a fila, o owner marca como
     * invalida em vez de deixar o cron batendo no mesmo item para sempre.
     */
    function invalidarSolicitacao(uint256 requestId) external onlyOwner {
        require(requestId < solicitacoes.length, "requestId inexistente");
        Solicitacao storage sol = solicitacoes[requestId];
        require(sol.status == StatusSolicitacao.PENDENTE, "Solicitacao ja processada");

        sol.status = StatusSolicitacao.INVALIDA;
        sol.processadaEm = block.timestamp;
        temSolicitacaoAberta[keccak256(abi.encode(sol.nome))] = false;
        _avancarCursor();

        emit SolicitacaoProcessada(requestId, StatusSolicitacao.INVALIDA, 0, bytes32(0));
    }

    // ---------------------------------------------------------------
    // Analise — somente leitura, consumida pelo CRE via eth_call
    // ---------------------------------------------------------------

    function limparTexto(string memory str) internal pure returns (string memory) {
        bytes memory b = bytes(str);
        bytes memory temp = new bytes(b.length);
        uint j = 0;
        for (uint i = 0; i < b.length; i++) {
            bytes1 c = b[i];
            if (c == 0x2C || c == 0x2E || c == 0x3F || c == 0x21 || c == 0x2D || c == 0x26) continue;
            if (c >= 0x41 && c <= 0x5A) { temp[j++] = bytes1(uint8(c) + 32); } else { temp[j++] = c; }
        }
        bytes memory result = new bytes(j);
        for (uint i = 0; i < j; i++) result[i] = temp[i];
        return string(result);
    }

    function splitWords(string memory str) internal pure returns (string[5] memory words, uint count) {
        bytes memory b = bytes(str);
        uint start = 0; count = 0;
        for (uint i = 0; i <= b.length; i++) {
            if (i == b.length || b[i] == 0x20) {
                if (count < 5 && i > start) {
                    bytes memory word = new bytes(i - start);
                    for (uint j = start; j < i; j++) word[j - start] = b[j];
                    words[count++] = string(word);
                }
                start = i + 1;
            }
        }
    }

    function removerArtigos(string memory str) internal pure returns (string memory) {
        (string[5] memory words, uint count) = splitWords(str);
        bytes memory result;
        for (uint i = 0; i < count; i++) {
            bytes32 h = keccak256(bytes(words[i]));
            if (h == keccak256("o") || h == keccak256("a") || h == keccak256("os") ||
                h == keccak256("as") || h == keccak256("the")) continue;
            result = abi.encodePacked(result, words[i]);
            if (i < count - 1) result = abi.encodePacked(result, " ");
        }
        return string(result);
    }

    function removerEspacos(string memory str) internal pure returns (string memory) {
        bytes memory b = bytes(str);
        bytes memory temp = new bytes(b.length);
        uint j = 0;
        for (uint i = 0; i < b.length; i++) { if (b[i] != 0x20) temp[j++] = b[i]; }
        bytes memory result = new bytes(j);
        for (uint i = 0; i < j; i++) result[i] = temp[i];
        return string(result);
    }

    function normalizar(string memory str) internal pure returns (string memory) {
        return removerEspacos(removerArtigos(limparTexto(str)));
    }

    function temEspaco(string memory str) internal pure returns (bool) {
        bytes memory b = bytes(str);
        for (uint i = 0; i < b.length; i++) if (b[i] == 0x20) return true;
        return false;
    }

    function inverter(string memory str) internal pure returns (string memory) {
        bytes memory b = bytes(str);
        bytes memory rev = new bytes(b.length);
        for (uint i = 0; i < b.length; i++) rev[i] = b[b.length - 1 - i];
        return string(rev);
    }

    function reverseWords(string[5] memory words, uint count) internal pure returns (string memory) {
        bytes memory result;
        for (uint i = 0; i < count; i++) {
            uint idx = count - 1 - i;
            result = abi.encodePacked(result, words[idx]);
            if (i < count - 1) result = abi.encodePacked(result, " ");
        }
        return string(result);
    }

    function similarity(string memory a, string memory b) internal pure returns (uint256) {
        bytes memory ba = bytes(a); bytes memory bb = bytes(b);
        uint min = ba.length < bb.length ? ba.length : bb.length;
        if (min == 0) return 0;
        uint iguais = 0;
        for (uint i = 0; i < min; i++) if (ba[i] == bb[i]) iguais++;
        uint bytesScore = (iguais * 100) / min;
        uint lenDiff = ba.length > bb.length ? ba.length - bb.length : bb.length - ba.length;
        uint lenScore = lenDiff * 10 > 100 ? 0 : 100 - (lenDiff * 10);
        return (bytesScore * 70 + lenScore * 30) / 100;
    }

    function analisarBase(string memory q, string memory m) internal pure returns (uint256) {
        uint best = 0;
        uint s1 = similarity(q, m); if (s1 > best) best = s1;
        string memory rq = inverter(q);
        uint s2 = similarity(rq, m); if (s2 > best) best = s2;
        (string[5] memory words, uint count) = splitWords(q);
        if (count > 1) {
            string memory reordered = reverseWords(words, count);
            uint s3 = similarity(reordered, m); if (s3 > best) best = s3;
        }
        return best;
    }

    function gerarSplitScore(string memory query, string memory marca) internal pure returns (uint256) {
        bytes memory b = bytes(query);
        uint best = 0;
        for (uint i = 1; i < b.length; i++) {
            bytes memory left = new bytes(i);
            for (uint j = 0; j < i; j++) left[j] = b[j];
            bytes memory right = new bytes(b.length - i);
            for (uint j = i; j < b.length; j++) right[j - i] = b[j];
            string memory combined = string(abi.encodePacked(string(left), " ", string(right)));
            uint s = analisarBase(combined, marca); if (s > best) best = s;
        }
        return best;
    }

    function combinarPalavras(string memory str, string memory marca) internal pure returns (uint256) {
        (string[5] memory words, uint count) = splitWords(str);
        uint best = 0;
        for (uint i = 0; i < count; i++)
            for (uint j = i + 1; j < count; j++) {
                string memory combined = string(abi.encodePacked(words[i], words[j]));
                uint s = analisarBase(combined, marca); if (s > best) best = s;
            }
        return best;
    }

    function calcularScore(string memory query, string memory marca) internal pure returns (uint256) {
        string memory q = normalizar(query);
        string memory m = normalizar(marca);
        uint best = 0;
        uint base = analisarBase(q, m); if (base > best) best = base;
        if (temEspaco(q)) {
            uint s1 = combinarPalavras(q, m); if (s1 > best) best = s1;
            uint s2 = combinarPalavras(m, q); if (s2 > best) best = s2;
        } else {
            uint s3 = gerarSplitScore(q, m); if (s3 > best) best = s3;
            uint s4 = gerarSplitScore(m, q); if (s4 > best) best = s4;
        }
        return best;
    }

    /**
     * Chamado pelo CRE por eth_call: custo zero.
     */
    function analisar(string memory query) public view returns (
        uint256 score,
        string memory decision,
        string memory risk,
        string memory matchCom
    ) {
        uint256 best = 0;
        string memory bestNome = "";
        for (uint i = 0; i < listaMarcas.length; i++) {
            uint s = calcularScore(query, listaMarcas[i]);
            if (s > best) { best = s; bestNome = listaMarcas[i]; }
        }
        if (best >= LIMITE_REJEICAO) return (best, "REJECTED", "HIGH", bestNome);
        return (best, "APPROVED", "LOW", bestNome);
    }

    /**
     * Versao enxuta para o workflow: devolve o unico match vencedor, que o
     * CRE recalcula em TypeScript antes de reportar.
     */
    function analisarParaCRE(string memory query) external view returns (
        uint256 score,
        bytes32 matchHash,
        string memory matchNome
    ) {
        (uint256 best, , , string memory bestNome) = analisar(query);
        return (best, bytes(bestNome).length == 0 ? bytes32(0) : keccak256(bytes(bestNome)), bestNome);
    }

    function topMatches(string memory query) public view returns (Resultado[10] memory top) {
        for (uint i = 0; i < listaMarcas.length; i++) {
            uint s = calcularScore(query, listaMarcas[i]);
            for (uint j = 0; j < 10; j++) {
                if (s > top[j].score) {
                    for (uint k = 9; k > j; k--) top[k] = top[k - 1];
                    top[j] = Resultado(listaMarcas[i], s);
                    break;
                }
            }
        }
    }

    // ---------------------------------------------------------------
    // Consultas
    // ---------------------------------------------------------------

    function podeSolicitar(string memory nome) external view returns (bool, string memory) {
        bytes32 hash = keccak256(abi.encode(nome));
        if (registros[hash].timestamp != 0) return (false, "Marca ja registrada");
        if (temSolicitacaoAberta[hash]) return (false, "Solicitacao ja pendente");
        (, string memory decision, , ) = analisar(nome);
        if (keccak256(bytes(decision)) == keccak256(bytes("REJECTED"))) {
            return (false, "Marca muito similar - seria REJEITADA");
        }
        return (true, "Pode solicitar");
    }

    function transferir(string memory nome, address novoDono) public {
        bytes32 hash = keccak256(abi.encode(nome));
        Registro storage reg = registros[hash];
        require(reg.timestamp != 0, "Marca nao existe");
        require(reg.dono == msg.sender, "Apenas o dono pode transferir");
        require(novoDono != address(0), "Endereco invalido");
        address antigoDono = reg.dono;
        reg.dono = novoDono;
        emit MarcaTransferida(nome, antigoDono, novoDono);
    }

    function totalMarcas() public view returns (uint256) { return listaMarcas.length; }

    function getMarca(string memory nome) public view returns (string memory, address, uint256, uint256) {
        bytes32 hash = keccak256(abi.encode(nome));
        Registro memory reg = registros[hash];
        return (reg.nome, reg.dono, reg.timestamp, reg.score);
    }

    function getMarcasPorPagina(uint256 offset, uint256 limit) public view returns (string[] memory) {
        uint256 end = offset + limit;
        if (end > listaMarcas.length) end = listaMarcas.length;
        if (offset >= end) return new string[](0);
        string[] memory result = new string[](end - offset);
        for (uint i = offset; i < end; i++) result[i - offset] = listaMarcas[i];
        return result;
    }
}
