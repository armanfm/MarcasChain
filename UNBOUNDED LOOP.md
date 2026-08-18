# MarcasChain â€” estabilizaÃ§Ã£o do gas on-chain em uma varredura O(n)

**Autor:** Armando Freire  
**Rede:** Ethereum Sepolia  
**Contrato atual:** [`0x424d3b3Ef97eC8670441866a380b7C01a63594fE`](https://sepolia.etherscan.io/address/0x424d3b3Ef97eC8670441866a380b7C01a63594fE)

## Resumo

Este documento descreve uma mudanÃ§a de arquitetura aplicada a um smart contract que precisava comparar uma nova entrada com todos os registros existentes.

Na primeira versÃ£o, a comparaÃ§Ã£o completa acontecia dentro da prÃ³pria transaÃ§Ã£o de registro. Como a quantidade de iteraÃ§Ãµes dependia do tamanho da base, o gas crescia a cada novo registro. A funÃ§Ã£o funcionava em uma base pequena, mas carregava um **unbounded loop**: nÃ£o existia um limite fixo para o trabalho executado pela transaÃ§Ã£o.

A soluÃ§Ã£o nÃ£o foi eliminar o cÃ¡lculo nem reescrever todo o algoritmo. A soluÃ§Ã£o foi mudar **onde** ele acontece:

- a transaÃ§Ã£o do usuÃ¡rio apenas cria uma solicitaÃ§Ã£o pendente;
- o Chainlink CRE executa a leitura pesada por `eth_call`;
- o contrato normaliza os nomes, percorre a base e devolve atÃ© dez candidatos;
- uma API de IA faz a avaliaÃ§Ã£o semÃ¢ntica desses candidatos;
- somente um report pequeno retorna para atualizar o estado on-chain.

Com isso, o gas on-chain deixou de crescer com o nÃºmero de marcas registradas. Em uma execuÃ§Ã£o comparÃ¡vel na Sepolia, o fluxo completo caiu de **4.043.856 para 411.426 gas**, uma reduÃ§Ã£o de **89,8%**.

---

## 1. O problema original

A primeira arquitetura realizava a anÃ¡lise antes de gravar o registro:

```solidity
function registrar(string memory nome) public {
    (uint256 score, string memory decision, , ) = analisar(nome);

    require(
        keccak256(bytes(decision)) != keccak256(bytes("REJECTED")),
        "Marca rejeitada"
    );

    // grava o registro
}
```

Internamente, `analisar()` precisava percorrer toda a lista de marcas:

```solidity
for (uint256 i = 0; i < listaMarcas.length; i++) {
    uint256 score = calcularScore(nome, listaMarcas[i]);
    // mantÃ©m o melhor resultado
}
```

Considerando `N` como o nÃºmero de marcas, o trabalho da transaÃ§Ã£o crescia, no mÃ­nimo, de forma linear em relaÃ§Ã£o Ã  base. O cÃ¡lculo real tambÃ©m dependia do comprimento dos nomes, das normalizaÃ§Ãµes, das comparaÃ§Ãµes auxiliares e das alocaÃ§Ãµes de memÃ³ria.

O problema nÃ£o era simplesmente â€œum loop em Solidityâ€. Loops com limites pequenos e conhecidos sÃ£o normais. O problema era o limite depender de uma coleÃ§Ã£o que poderia crescer indefinidamente.

### ConsequÃªncia

Cada marca adicionada aumentava o trabalho necessÃ¡rio para executar o prÃ³ximo `registrar()`. Portanto:

```text
mais registros â†’ mais iteraÃ§Ãµes â†’ mais gas â†’ maior risco de bloqueio da funÃ§Ã£o
```

Quando o consumo necessÃ¡rio ultrapassa o gas disponÃ­vel para uma transaÃ§Ã£o ou o limite aceito pelo bloco, aumentar o pagamento nÃ£o resolve: a operaÃ§Ã£o deixa de caber.

---

## 2. Por que declarar a funÃ§Ã£o como `view` nÃ£o resolvia

Uma funÃ§Ã£o `view` nÃ£o Ã© automaticamente gratuita.

- Quando chamada externamente por `eth_call`, ela Ã© executada localmente pelo nÃ³ e nÃ£o gera uma transaÃ§Ã£o paga pelo usuÃ¡rio.
- Quando chamada internamente por uma funÃ§Ã£o que altera estado, sua computaÃ§Ã£o faz parte da transaÃ§Ã£o e consome gas normalmente.

Na arquitetura antiga, `registrar()` chamava a anÃ¡lise `view` durante a prÃ³pria transaÃ§Ã£o. Logo, toda a varredura era cobrada e precisava caber no bloco.

A mudanÃ§a decisiva foi retirar essa chamada do caminho transacional.

---

## 3. A arquitetura simplificada

```mermaid
flowchart TD
    U["UsuÃ¡rio solicita o registro"] --> P["Contrato grava pedido pendente â€” O(1)"]
    P --> C["Chainlink CRE lÃª o pedido"]
    C --> V["topMatches via eth_call â€” O(N) fora da transaÃ§Ã£o"]
    V --> I["API de IA avalia atÃ© 10 candidatos"]
    I --> R["CRE envia report â€” O(1) em relaÃ§Ã£o Ã  base"]
    R --> S["Contrato grava o veredito"]
```

### Etapa 1 â€” SolicitaÃ§Ã£o

O usuÃ¡rio chama `solicitarRegistro(nome)`. Essa funÃ§Ã£o valida a entrada e grava uma solicitaÃ§Ã£o pendente, mas nÃ£o percorre a base.

Seu custo nÃ£o aumenta quando novas marcas sÃ£o registradas.

### Etapa 2 â€” Leitura pelo CRE

O workflow identifica a prÃ³xima solicitaÃ§Ã£o pendente por meio de uma chamada de leitura.

### Etapa 3 â€” ComparaÃ§Ã£o por `eth_call`

O CRE chama `topMatches(nome)` por `eth_call`. O contrato:

1. normaliza a entrada;
2. percorre a base existente;
3. calcula os scores de similaridade;
4. mantÃ©m somente os dez candidatos mais prÃ³ximos.

O cÃ¡lculo continua sendo O(N) em relaÃ§Ã£o ao nÃºmero de marcas, mas nÃ£o ocorre dentro da transaÃ§Ã£o do usuÃ¡rio.

### Etapa 4 â€” AvaliaÃ§Ã£o semÃ¢ntica

O workflow envia os candidatos para uma API de IA. Essa etapa complementa o cÃ¡lculo posicional em casos de semelhanÃ§a fonÃ©tica, termos genÃ©ricos e significado prÃ³prio.

A IA nÃ£o Ã© responsÃ¡vel pela reduÃ§Ã£o de gas. A reduÃ§Ã£o jÃ¡ acontece quando a varredura sai da transaÃ§Ã£o. A IA Ã© uma segunda camada para melhorar a decisÃ£o produzida a partir dos candidatos.

### Etapa 5 â€” Report

Depois do processamento, o CRE assina e envia um report contendo apenas os dados necessÃ¡rios para concluir a solicitaÃ§Ã£o. O contrato valida a origem do report e grava o veredito.

O nÃºmero de marcas nÃ£o altera a quantidade de registros gravados por esse report. Assim, seu gas permanece estÃ¡vel em relaÃ§Ã£o ao tamanho da base.

---

## 4. O que foi simplificado

A soluÃ§Ã£o evitou adicionar uma infraestrutura desnecessariamente complexa ao problema.

| Possibilidade | ConsequÃªncia | DecisÃ£o adotada |
|---|---|---|
| Manter a varredura no `registrar()` | Gas crescente e risco de indisponibilidade | Removida do caminho transacional |
| Apenas migrar para uma L2 | Reduz o preÃ§o, mas o loop continua crescendo | NÃ£o trata a causa |
| Criar circuito ZK ou coprocessador verificÃ¡vel | Maior complexidade de implementaÃ§Ã£o | DesnecessÃ¡rio para o protÃ³tipo |
| Reescrever todo o matching | Risco de introduzir novos erros | NÃºcleo do cÃ¡lculo preservado |
| Executar a leitura por `eth_call` e retornar um report | Poucas mudanÃ§as e escrita final pequena | SoluÃ§Ã£o escolhida |

A simplificaÃ§Ã£o pode ser resumida em uma frase:

> **O cÃ¡lculo nÃ£o foi eliminado; foi retirado da transaÃ§Ã£o.**

Essa separaÃ§Ã£o criou dois caminhos distintos:

- **caminho de escrita:** pequeno, previsÃ­vel e estÃ¡vel em relaÃ§Ã£o Ã  base;
- **caminho de computaÃ§Ã£o:** pesado, assÃ­ncrono e executado fora da transaÃ§Ã£o do usuÃ¡rio.

---

## 5. Resultado medido na Sepolia

As trÃªs transaÃ§Ãµes abaixo pertencem a uma sequÃªncia comparÃ¡vel de testes.

| Etapa | Gas usado | RelaÃ§Ã£o com o tamanho da base | TransaÃ§Ã£o |
|---|---:|---|---|
| Registro na arquitetura antiga | **4.043.856** | Cresce conforme novas marcas sÃ£o adicionadas | [`0x608778â€¦`](https://sepolia.etherscan.io/tx/0x60877890b3ac7ed9574d9dc3701a7213b36749d7f4f6d86839317365fe2fc6cb) |
| SolicitaÃ§Ã£o na nova arquitetura | **152.469** | EstÃ¡vel em relaÃ§Ã£o ao nÃºmero de marcas | [`0xef2f73â€¦`](https://sepolia.etherscan.io/tx/0xef2f733dbef15a0b035d873934ef61615ee6666207f16389d23160348bcb0730) |
| Report final do Chainlink CRE | **258.957** | EstÃ¡vel em relaÃ§Ã£o ao nÃºmero de marcas | [`0x8241c8â€¦`](https://sepolia.etherscan.io/tx/0x8241c817210934110a3dbf246f3500f2a552850603b166ed3eba877c0e44b0a6) |
| **Novo fluxo on-chain completo** | **411.426** | **EstÃ¡vel em relaÃ§Ã£o ao nÃºmero de marcas** | SolicitaÃ§Ã£o + report |

### CÃ¡lculo da reduÃ§Ã£o

```text
Fluxo antigo: 4.043.856 gas
Fluxo novo:     411.426 gas
Economia:     3.632.430 gas
ReduÃ§Ã£o:          89,8%
```

O novo fluxo completo utilizou aproximadamente **9,83 vezes menos gas**.

O ganho principal nÃ£o Ã© apenas uma transaÃ§Ã£o especÃ­fica ter ficado mais barata. A mudanÃ§a mais importante Ã© estrutural:

- antes, o gas on-chain crescia com `N`;
- depois, o gas on-chain permanece estÃ¡vel em relaÃ§Ã£o a `N`.

Os valores absolutos ainda podem variar por tamanho do payload, caminho de aprovaÃ§Ã£o ou rejeiÃ§Ã£o e alteraÃ§Ãµes de storage. Essa variaÃ§Ã£o nÃ£o Ã© causada pelo crescimento da base de marcas.

---

## 6. Complexidade antes e depois

Nesta tabela, a complexidade considera o crescimento do nÃºmero `N` de marcas registradas.

| OperaÃ§Ã£o | Arquitetura antiga | Nova arquitetura |
|---|---:|---:|
| SolicitaÃ§Ã£o do usuÃ¡rio | O(N) on-chain | O(1) on-chain |
| NormalizaÃ§Ã£o e matching | O(N) on-chain | O(N) via `eth_call` |
| AvaliaÃ§Ã£o semÃ¢ntica | NÃ£o existia | Fora da blockchain |
| Escrita do resultado | IncluÃ­da na operaÃ§Ã£o O(N) | O(1) em relaÃ§Ã£o Ã  base |

O trabalho total de comparaÃ§Ã£o nÃ£o se tornou constante. O que se tornou constante em relaÃ§Ã£o Ã  base foi o caminho de gas on-chain.

---

## 7. Limites e trade-offs

### O `eth_call` tambÃ©m possui limites

Embora nÃ£o cobre gas transacional do usuÃ¡rio, o nÃ³ ainda precisa executar a computaÃ§Ã£o. Uma base suficientemente grande pode atingir timeout ou limite de execuÃ§Ã£o do provedor RPC.

Portanto, a soluÃ§Ã£o remove a bomba de gas on-chain e amplia bastante a escala suportada, mas nÃ£o transforma uma varredura O(N) em computaÃ§Ã£o ilimitada. Em uma evoluÃ§Ã£o de produÃ§Ã£o, a busca de candidatos poderia migrar para um Ã­ndice off-chain, processamento em lotes ou outra estrutura apropriada.

### O report pode variar entre aprovaÃ§Ã£o e rejeiÃ§Ã£o

Uma aprovaÃ§Ã£o pode exigir mais escritas de storage que uma rejeiÃ§Ã£o. Essa diferenÃ§a altera o valor absoluto do gas, mas continua independente do nÃºmero de marcas usadas na comparaÃ§Ã£o.

### Cursor da fila

Se a implementaÃ§Ã£o de avanÃ§o da fila percorrer solicitaÃ§Ãµes processadas para encontrar a prÃ³xima pendente, poderÃ¡ existir crescimento residual relacionado ao histÃ³rico da fila. Isso Ã© separado do unbounded loop da base de marcas e pode ser removido com um ponteiro explÃ­cito para a prÃ³xima solicitaÃ§Ã£o.

### DependÃªncias externas

O workflow depende da disponibilidade do CRE, do RPC e da API de IA. A solicitaÃ§Ã£o deve permanecer pendente quando essas etapas falham, permitindo nova tentativa sem registrar uma aprovaÃ§Ã£o silenciosa.

### Escopo jurÃ­dico

O sistema Ã© um protÃ³tipo tÃ©cnico de triagem e registro experimental. Ele nÃ£o consulta toda a base oficial, nÃ£o substitui uma anÃ¡lise jurÃ­dica e nÃ£o concede direitos de marca, atribuiÃ§Ã£o exclusiva do INPI no Brasil.

---

## 8. Componentes

### Smart contract

- recebe solicitaÃ§Ãµes;
- mantÃ©m o estado pendente;
- expÃµe `getNextPendingRequest()` e `topMatches()` para leitura;
- recebe reports autorizados;
- registra o resultado final.

### Workflow Chainlink CRE

- dispara de forma agendada;
- consulta a fila;
- chama `topMatches()` por `eth_call`;
- envia os candidatos Ã  API de IA;
- produz o report assinado;
- atualiza o contrato.

### Frontend

- envia a solicitaÃ§Ã£o pela carteira;
- acompanha o estado pendente;
- apresenta o veredito e os candidatos analisados.

---

## 9. EndereÃ§os da implementaÃ§Ã£o

| Componente | EndereÃ§o na Sepolia |
|---|---|
| Contrato MarcasChain | [`0x424d3b3Ef97eC8670441866a380b7C01a63594fE`](https://sepolia.etherscan.io/address/0x424d3b3Ef97eC8670441866a380b7C01a63594fE) |
| Receiver/Forwarder usado no report do CRE | [`0x15fC6ae953E024d975e77382eEeC56A9101f9F88`](https://sepolia.etherscan.io/address/0x15fC6ae953E024d975e77382eEeC56A9101f9F88) |

---

## ConclusÃ£o

O problema resolvido foi o crescimento do gas causado por uma varredura sem limite fixo dentro de uma funÃ§Ã£o transacional.

A soluÃ§Ã£o foi simples porque nÃ£o tentou transformar todo o algoritmo nem adicionar provas criptogrÃ¡ficas complexas. Ela separou responsabilidades:

1. o usuÃ¡rio solicita;
2. o CRE processa;
3. o contrato recebe somente o resultado.

O loop continua existindo e a computaÃ§Ã£o ainda cresce com a base, mas isso acontece fora da transaÃ§Ã£o. A solicitaÃ§Ã£o e o report permanecem estÃ¡veis em relaÃ§Ã£o ao nÃºmero de marcas.

> **Antes, cada novo registro tornava a prÃ³xima transaÃ§Ã£o mais cara. Depois, a base pode crescer sem aumentar o gas on-chain do fluxo de solicitaÃ§Ã£o e resposta.**
