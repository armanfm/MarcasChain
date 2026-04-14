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
    
    mapping(bytes32 => Registro) public registros;
    string[] public listaMarcas;
    
    address public owner;
    
    event MarcaRegistrada(string indexed nome, address indexed dono, uint256 score, bool veioDaGovernanca);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Nao autorizado");
        _;
    }

    // ========== FUNÇÕES DE ANÁLISE ==========

    function limparTexto(string memory str) internal pure returns (string memory) {
        bytes memory b = bytes(str);
        bytes memory temp = new bytes(b.length);
        uint j = 0;

        for (uint i = 0; i < b.length; i++) {
            bytes1 c = b[i];

            if (
                c == 0x2C || c == 0x2E || c == 0x3F ||
                c == 0x21 || c == 0x2D || c == 0x26
            ) continue;

            if (c >= 0x41 && c <= 0x5A) {
                temp[j++] = bytes1(uint8(c) + 32);
            } else {
                temp[j++] = c;
            }
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
            if (s > best) {
                best = s;
                bestNome = listaMarcas[i];
            }
        }

        if (best >= 70) {
            return (best, "REJECTED", "HIGH", bestNome);
        } else {
            return (best, "APPROVED", "LOW", bestNome);
        }
    }

    function topMatches(string memory query) public view returns (Resultado[10] memory top) {
        for (uint i = 0; i < listaMarcas.length; i++) {
            uint s = calcularScore(query, listaMarcas[i]);
            for (uint j = 0; j < 10; j++) {
                if (s > top[j].score) {
                    for (uint k = 9; k > j; k--) {
                        top[k] = top[k - 1];
                    }
                    top[j] = Resultado(listaMarcas[i], s);
                    break;
                }
            }
        }
    }

    // ========== FUNÇÃO PRINCIPAL ==========
    // 🔥 Registrar marca e pagar tempo TUDO EM UM
    // O valor enviado vai TODO para o MarcasTempo

    function registrar(string memory nome, address contratoTempo, uint256 anos) public payable {
        bytes32 hash = keccak256(abi.encode(nome));
        require(registros[hash].timestamp == 0, "Marca ja registrada");

        (uint256 score, string memory decision, , ) = analisar(nome);

        require(
            keccak256(bytes(decision)) != keccak256(bytes("REJECTED")),
            "Marca muito similar - REJEITADA"
        );

        // Registra a marca
        registros[hash] = Registro({
            nome: nome,
            dono: msg.sender,
            timestamp: block.timestamp,
            score: score,
            veioDaGovernanca: false
        });

        listaMarcas.push(nome);

        // Paga o tempo (todo o valor enviado vai pro MarcasTempo)
        (bool successTempo, ) = contratoTempo.call{value: msg.value}(
            abi.encodeWithSignature("pagarTempo(string,uint256)", nome, anos)
        );
        require(successTempo, "Falha ao pagar tempo");

        emit MarcaRegistrada(nome, msg.sender, score, false);
    }

    // ========== FUNÇÕES DE CONSULTA ==========

    function podeRegistrar(string memory nome) public view returns (bool, string memory) {
        bytes32 hash = keccak256(abi.encode(nome));

        if (registros[hash].timestamp != 0) {
            return (false, "Marca ja registrada");
        }

        (, string memory decision, , ) = analisar(nome);

        if (keccak256(bytes(decision)) == keccak256(bytes("REJECTED"))) {
            return (false, "Marca muito similar - REJEITADA");
        }

        return (true, "Pode registrar");
    }

    function totalMarcas() public view returns (uint256) {
        return listaMarcas.length;
    }
    
    function getMarca(string memory nome) public view returns (
        string memory, address, uint256, uint256, bool
    ) {
        bytes32 hash = keccak256(abi.encode(nome));
        Registro memory reg = registros[hash];
        return (reg.nome, reg.dono, reg.timestamp, reg.score, reg.veioDaGovernanca);
    }
}
