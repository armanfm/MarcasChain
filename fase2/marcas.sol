// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Marcas {

    struct Registro {
        string nome;
        address dono;
        uint256 timestamp;
        uint256 score;
        bool veioDaGovernanca;
    }

    struct Resultado {
        string nome;
        uint256 score;
    }
    
    struct Solicitacao {
        address solicitante;
        uint256 score;
        uint256 timestamp;
        uint256 stake;
        bool processada;
        bool aprovada;
    }

    mapping(bytes32 => Registro) public registros;
    string[] public listaMarcas;
    
    mapping(bytes32 => Solicitacao) public solicitacoes;
    mapping(bytes32 => string) public nomeDaSolicitacao;
    bytes32[] public listaSolicitacoes;
    
    address public owner;
    uint256 public precoRegistro = 0.1 ether;
    
    event MarcaRegistrada(string indexed nome, address indexed dono, uint256 score, bool veioDaGovernanca);
    event SolicitacaoCriada(string indexed nome, address indexed solicitante, uint256 score, uint256 stake);
    event SolicitacaoAprovada(string indexed nome, address indexed dono, uint256 stakeUtilizado);
    event SolicitacaoRejeitada(string indexed nome, uint256 stakeDevolvido);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Nao autorizado");
        _;
    }

    // ========== VALIDAÇÃO DE FORMATO ==========
    function isValidFormat(string memory str) internal pure returns (bool) {
        bytes memory b = bytes(str);
        require(b.length > 0 && b.length <= 50, "Tamanho invalido");
        
        for (uint i = 0; i < b.length; i++) {
            bytes1 c = b[i];
            
            bool isLower = (c >= 0x61 && c <= 0x7A); // a-z
            bool isNumber = (c >= 0x30 && c <= 0x39); // 0-9
            bool isSpace = (c == 0x20);
            
            require(isLower || isNumber || isSpace, "Caractere invalido: use apenas a-z, 0-9 e espaco");
            
            // Nao permite dois espacos consecutivos
            if (isSpace && i > 0 && b[i-1] == 0x20) {
                return false;
            }
        }
        
        require(b[0] != 0x20, "Nao pode comecar com espaco");
        require(b[b.length-1] != 0x20, "Nao pode terminar com espaco");
        
        return true;
    }

    // ========== FUNÇÕES DE ANÁLISE (OTIMIZADAS) ==========
    
    // Remove pontuação (já vem minúsculo e sem acentos do frontend)
    function limparTexto(string memory str) internal pure returns (string memory) {
        bytes memory b = bytes(str);
        bytes memory temp = new bytes(b.length);
        uint j = 0;

        for (uint i = 0; i < b.length; i++) {
            bytes1 c = b[i];

            // Remove pontuação: , . ? ! - &
            if (
                c == 0x2C || c == 0x2E || c == 0x3F ||
                c == 0x21 || c == 0x2D || c == 0x26
            ) continue;

            temp[j++] = c;
        }

        bytes memory result = new bytes(j);
        for (uint i = 0; i < j; i++) result[i] = temp[i];

        return string(result);
    }

    function splitWords(string memory str) internal pure returns (string[5] memory words, uint count) {
        bytes memory b = bytes(str);
        uint start = 0;
        count = 0;

        for (uint i = 0; i <= b.length; i++) {
            if (i == b.length || b[i] == 0x20) {
                if (count < 5 && i > start) {
                    bytes memory word = new bytes(i - start);
                    for (uint j = start; j < i; j++) {
                        word[j - start] = b[j];
                    }
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

            if (
                h == keccak256("o") ||
                h == keccak256("a") ||
                h == keccak256("os") ||
                h == keccak256("as") ||
                h == keccak256("the")
            ) continue;

            result = abi.encodePacked(result, words[i]);

            if (i < count - 1) {
                result = abi.encodePacked(result, " ");
            }
        }

        return string(result);
    }

    function removerEspacos(string memory str) internal pure returns (string memory) {
        bytes memory b = bytes(str);
        bytes memory temp = new bytes(b.length);
        uint j = 0;

        for (uint i = 0; i < b.length; i++) {
            if (b[i] != 0x20) {
                temp[j++] = b[i];
            }
        }

        bytes memory result = new bytes(j);
        for (uint i = 0; i < j; i++) {
            result[i] = temp[i];
        }

        return string(result);
    }

    function normalizar(string memory str) internal pure returns (string memory) {
        return removerEspacos(removerArtigos(limparTexto(str)));
    }

    function temEspaco(string memory str) internal pure returns (bool) {
        bytes memory b = bytes(str);
        for (uint i = 0; i < b.length; i++) {
            if (b[i] == 0x20) return true;
        }
        return false;
    }

    function inverter(string memory str) internal pure returns (string memory) {
        bytes memory b = bytes(str);
        bytes memory rev = new bytes(b.length);
        for (uint i = 0; i < b.length; i++) {
            rev[i] = b[b.length - 1 - i];
        }
        return string(rev);
    }

    function reverseWords(string[5] memory words, uint count) internal pure returns (string memory) {
        bytes memory result;
        for (uint i = 0; i < count; i++) {
            uint idx = count - 1 - i;
            result = abi.encodePacked(result, words[idx]);
            if (i < count - 1) {
                result = abi.encodePacked(result, " ");
            }
        }
        return string(result);
    }

    function similarity(string memory a, string memory b) internal pure returns (uint256) {
        bytes memory ba = bytes(a);
        bytes memory bb = bytes(b);
        uint min = ba.length < bb.length ? ba.length : bb.length;
        if (min == 0) return 0;
        uint iguais = 0;
        for (uint i = 0; i < min; i++) {
            if (ba[i] == bb[i]) iguais++;
        }
        uint bytesScore = (iguais * 100) / min;
        uint lenDiff = ba.length > bb.length ? ba.length - bb.length : bb.length - ba.length;
        uint lenScore = lenDiff * 10 > 100 ? 0 : 100 - (lenDiff * 10);
        return (bytesScore * 70 + lenScore * 30) / 100;
    }

    function analisarBase(string memory q, string memory m) internal pure returns (uint256) {
        uint best = 0;
        uint s1 = similarity(q, m);
        if (s1 > best) best = s1;
        string memory rq = inverter(q);
        uint s2 = similarity(rq, m);
        if (s2 > best) best = s2;
        (string[5] memory words, uint count) = splitWords(q);
        if (count > 1) {
            string memory reordered = reverseWords(words, count);
            uint s3 = similarity(reordered, m);
            if (s3 > best) best = s3;
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
            uint s = analisarBase(combined, marca);
            if (s > best) best = s;
        }
        return best;
    }

    function combinarPalavras(string memory str, string memory marca) internal pure returns (uint256) {
        (string[5] memory words, uint count) = splitWords(str);
        uint best = 0;
        for (uint i = 0; i < count; i++) {
            for (uint j = i + 1; j < count; j++) {
                string memory combined = string(abi.encodePacked(words[i], words[j]));
                uint s = analisarBase(combined, marca);
                if (s > best) best = s;
            }
        }
        return best;
    }

    function calcularScore(string memory query, string memory marca) internal pure returns (uint256) {
        string memory q = normalizar(query);
        string memory m = normalizar(marca);
        uint best = 0;
        uint base = analisarBase(q, m);
        if (base > best) best = base;
        if (temEspaco(q)) {
            uint s1 = combinarPalavras(q, m);
            if (s1 > best) best = s1;
            uint s2 = combinarPalavras(m, q);
            if (s2 > best) best = s2;
        } else {
            uint s3 = gerarSplitScore(q, m);
            if (s3 > best) best = s3;
            uint s4 = gerarSplitScore(m, q);
            if (s4 > best) best = s4;
        }
        return best;
    }

    function analisarComPendentes(string memory query) public view returns (uint256 score, string memory decision, string memory risk) {
        uint256 best = 0;
        
        // Compara com marcas já registradas
        for (uint i = 0; i < listaMarcas.length; i++) {
            uint s = calcularScore(query, listaMarcas[i]);
            if (s > best) best = s;
        }
        
        // Compara com marcas em solicitação (pendentes)
        for (uint i = 0; i < listaSolicitacoes.length; i++) {
            bytes32 hash = listaSolicitacoes[i];
            string memory nomeSolicitacao = nomeDaSolicitacao[hash];
            uint s = calcularScore(query, nomeSolicitacao);
            if (s > best) best = s;
        }
        
        if (best > 72) return (best, "REJECTED", "HIGH");
        if (best >= 70) return (best, "GOVERNANCE", "MEDIUM");
        if (best >= 50) return (best, "GRAY_ZONE", "MEDIUM");
        return (best, "APPROVED", "LOW");
    }

    function topMatchesComPendentes(string memory query) public view returns (Resultado[10] memory top) {
        // Cria array temporária com todas as marcas (registradas + solicitadas)
        uint totalItems = listaMarcas.length + listaSolicitacoes.length;
        string[] memory todasMarcas = new string[](totalItems);
        
        // Adiciona marcas registradas
        for (uint i = 0; i < listaMarcas.length; i++) {
            todasMarcas[i] = listaMarcas[i];
        }
        
        // Adiciona marcas em solicitação
        for (uint i = 0; i < listaSolicitacoes.length; i++) {
            bytes32 hash = listaSolicitacoes[i];
            todasMarcas[listaMarcas.length + i] = nomeDaSolicitacao[hash];
        }
        
        // Calcula scores e popula top 10
        for (uint i = 0; i < totalItems; i++) {
            uint s = calcularScore(query, todasMarcas[i]);
            
            for (uint j = 0; j < 10; j++) {
                if (s > top[j].score) {
                    for (uint k = 9; k > j; k--) {
                        top[k] = top[k - 1];
                    }
                    top[j] = Resultado(todasMarcas[i], s);
                    break;
                }
            }
        }
    }

    // Mantém a função original para compatibilidade
    function analisar(string memory query) public view returns (uint256 score, string memory decision, string memory risk) {
        return analisarComPendentes(query);
    }

    // ========== FUNÇÕES PRINCIPAIS ==========
    
    function registrarComPagamento(string memory nome) public payable {
        require(isValidFormat(nome), "Formato invalido: use apenas a-z, 0-9 e espaco (sem maiusculas, sem acentos)");
        require(msg.value >= precoRegistro, "Valor insuficiente");
        
        bytes32 hash = keccak256(bytes(nome)); // CORRIGIDO: bytes(nome) ao invés de abi.encode
        require(registros[hash].timestamp == 0, "Ja registrada");
        
        (uint256 score, string memory decision, ) = analisarComPendentes(nome);
        
        require(
            keccak256(bytes(decision)) != keccak256(bytes("REJECTED")),
            "Marca muito similar - REJEITADA"
        );
        
        require(
            keccak256(bytes(decision)) != keccak256(bytes("GOVERNANCE")),
            "Use solicitarComStake() para esta marca"
        );
        
        registros[hash] = Registro({
            nome: nome,
            dono: msg.sender,
            timestamp: block.timestamp,
            score: score,
            veioDaGovernanca: false
        });
        
        listaMarcas.push(nome);
        
        (bool sent, ) = owner.call{value: msg.value}("");
        require(sent, "Falha ao enviar pagamento");
        
        emit MarcaRegistrada(nome, msg.sender, score, false);
    }
    
    function solicitarComStake(string memory nome) public payable {
        require(isValidFormat(nome), "Formato invalido: use apenas a-z, 0-9 e espaco (sem maiusculas, sem acentos)");
        require(msg.value >= precoRegistro, "Stake insuficiente");
        
        bytes32 hash = keccak256(bytes(nome)); // CORRIGIDO: bytes(nome) ao invés de abi.encode
        require(registros[hash].timestamp == 0, "Ja registrada");
        require(solicitacoes[hash].timestamp == 0, "Solicitacao ja existe");
        
        (uint256 score, string memory decision, ) = analisarComPendentes(nome);
        
        require(
            keccak256(bytes(decision)) == keccak256(bytes("GOVERNANCE")),
            "Marca nao requer governanca. Use registrarComPagamento()"
        );
        
        solicitacoes[hash] = Solicitacao({
            solicitante: msg.sender,
            score: score,
            timestamp: block.timestamp,
            stake: msg.value,
            processada: false,
            aprovada: false
        });
        
        nomeDaSolicitacao[hash] = nome;
        listaSolicitacoes.push(hash);
        
        emit SolicitacaoCriada(nome, msg.sender, score, msg.value);
    }
    
    // ========== GOVERNANÇA ==========
    
    function getSolicitacoesPendentes() public view returns (string[] memory, address[] memory, uint256[] memory, uint256[] memory) {
        uint count = listaSolicitacoes.length;
        
        string[] memory nomes = new string[](count);
        address[] memory solicitantes = new address[](count);
        uint256[] memory scores = new uint256[](count);
        uint256[] memory stakes = new uint256[](count);
        
        for (uint i = 0; i < count; i++) {
            bytes32 hash = listaSolicitacoes[i];
            nomes[i] = nomeDaSolicitacao[hash];
            solicitantes[i] = solicitacoes[hash].solicitante;
            scores[i] = solicitacoes[hash].score;
            stakes[i] = solicitacoes[hash].stake;
        }
        
        return (nomes, solicitantes, scores, stakes);
    }
    
    function aprovarSolicitacao(string memory nome) public onlyOwner {
        bytes32 hash = keccak256(bytes(nome)); // CORRIGIDO: bytes(nome) ao invés de abi.encode
        
        Solicitacao storage sol = solicitacoes[hash];
        require(sol.timestamp != 0, "Solicitacao nao existe");
        require(!sol.processada, "Ja processada");
        require(registros[hash].timestamp == 0, "Marca ja registrada");
        
        // REANÁLISE: verifica se ainda está na faixa de governança
        (, string memory decision, ) = analisarComPendentes(nome);
        
        if (keccak256(bytes(decision)) != keccak256(bytes("GOVERNANCE"))) {
            // Se saiu da faixa, devolve stake e rejeita
            (bool sentRefund, ) = sol.solicitante.call{value: sol.stake}("");
            require(sentRefund, "Falha ao devolver stake");
            
            delete solicitacoes[hash];
            delete nomeDaSolicitacao[hash];
            _removerDaLista(hash);
            
            emit SolicitacaoRejeitada(nome, sol.stake);
            return;
        }
        
        // APROVA - usa o score ORIGINAL da solicitação (consistência)
        registros[hash] = Registro({
            nome: nome,
            dono: sol.solicitante,
            timestamp: block.timestamp,
            score: sol.score, // Score original, não o atual
            veioDaGovernanca: true
        });
        
        listaMarcas.push(nome);
        
        // STAKE vira pagamento
        (bool sent, ) = owner.call{value: sol.stake}("");
        require(sent, "Falha ao enviar pagamento");
        
        sol.processada = true;
        sol.aprovada = true;
        
        _removerDaLista(hash);
        
        emit SolicitacaoAprovada(nome, sol.solicitante, sol.stake);
        emit MarcaRegistrada(nome, sol.solicitante, sol.score, true);
    }
    
    function rejeitarSolicitacao(string memory nome) public onlyOwner {
        bytes32 hash = keccak256(bytes(nome)); // CORRIGIDO: bytes(nome) ao invés de abi.encode
        
        Solicitacao storage sol = solicitacoes[hash];
        require(sol.timestamp != 0, "Solicitacao nao existe");
        require(!sol.processada, "Ja processada");
        
        (bool sent, ) = sol.solicitante.call{value: sol.stake}("");
        require(sent, "Falha ao devolver stake");
        
        delete solicitacoes[hash];
        delete nomeDaSolicitacao[hash];
        _removerDaLista(hash);
        
        emit SolicitacaoRejeitada(nome, sol.stake);
    }
    
    function _removerDaLista(bytes32 hash) internal {
        for (uint i = 0; i < listaSolicitacoes.length; i++) {
            if (listaSolicitacoes[i] == hash) {
                listaSolicitacoes[i] = listaSolicitacoes[listaSolicitacoes.length - 1];
                listaSolicitacoes.pop();
                break;
            }
        }
    }
    
    // ========== FUNÇÕES DE CONSULTA ==========
    
    function podeRegistrar(string memory nome) public view returns (bool, string memory) {
        require(isValidFormat(nome), "Formato invalido: use apenas a-z, 0-9 e espaco"); // CORRIGIDO: adicionada validação
        
        bytes32 hash = keccak256(bytes(nome)); // CORRIGIDO: bytes(nome) ao invés de abi.encode
        
        if (registros[hash].timestamp != 0) {
            return (false, "Marca ja registrada");
        }
        
        ( , string memory decision, ) = analisarComPendentes(nome);
        
        if (keccak256(bytes(decision)) == keccak256("REJECTED")) {
            return (false, "Marca muito similar - REJEITADA");
        }
        
        if (keccak256(bytes(decision)) == keccak256("GOVERNANCE")) {
            if (solicitacoes[hash].timestamp == 0) {
                return (false, "Use solicitarComStake() para submeter a governanca");
            }
            if (!solicitacoes[hash].aprovada) {
                return (false, "Aguardando aprovacao da governanca");
            }
            return (true, "Aprovada - pode registrar");
        }
        
        return (true, "Use registrarComPagamento()");
    }
    
    function totalMarcas() public view returns (uint256) {
        return listaMarcas.length;
    }
    
    function totalSolicitacoes() public view returns (uint256) {
        return listaSolicitacoes.length;
    }
    
    function setPrecoRegistro(uint256 novoPreco) public onlyOwner {
        precoRegistro = novoPreco;
    }
}
