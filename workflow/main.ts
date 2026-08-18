import {
  CronCapability,
  HTTPClient,
  handler,
  Runner,
  consensusIdenticalAggregation,
  bytesToHex,
  cre,
  encodeCallMsg,
  type Runtime,
} from "@chainlink/cre-sdk";

import {
  decodeFunctionResult,
  encodeAbiParameters,
  encodeFunctionData,
  keccak256,
  parseAbi,
  parseAbiParameters,
  toBytes,
  zeroAddress,
  zeroHash,
} from "viem";

export type Config = {
  schedule?: string;
  contractAddress: `0x${string}`;
  geminiKey: string;
};

const NEXT_PENDING_REQUEST_ABI = parseAbi([
  "function getNextPendingRequest() view returns (bool found, uint256 requestId, string nome)",
]);

const TOP_MATCHES_ABI = parseAbi([
  "function topMatches(string query) view returns ((string nome, uint256 score)[10])",
]);

const REPORT_PARAMS = parseAbiParameters(
  "uint256 requestId, uint16 deterministicScore, bytes32 matchHash, uint32 algorithmVersion",
);

const REPORT_PREFIX = "01";
const ALGORITHM_VERSION = 3; // v3: Gemini decide sobre os 10 candidatos
const MAX_NAME_BYTES = 96;
const ETHEREUM_SEPOLIA_SELECTOR = BigInt("16015286601757825753");
const WRITE_GAS_LIMIT = "500000";

const GEMINI_MODEL = "gemini-2.5-flash";

// O contrato rejeita com score >= 70. Reportar 100 forca a rejeicao sem
// precisar alterar o contrato.
const SCORE_REJEICAO = 100;

// ------------------------------------------------------------------
// Utilitarios
// ------------------------------------------------------------------

function encodeBody(data: object) {
  return new TextEncoder().encode(JSON.stringify(data));
}

function bodyToText(body: any): string {
  if (!body) return "";
  if (typeof body === "string") return body;
  return new TextDecoder().decode(body);
}

function safeStringify(value: any): string {
  if (value === undefined) return "undefined";
  if (value === null) return "null";
  try {
    const text = JSON.stringify(value, (_key, val) =>
      typeof val === "bigint" ? val.toString() : val,
    );
    return text ?? String(value);
  } catch {
    return String(value);
  }
}

function hexToBase64(hex: string): string {
  const clean = hex.startsWith("0x") ? hex.slice(2) : hex;
  const alphabet =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  const bytes: number[] = [];

  for (let index = 0; index < clean.length; index += 2) {
    bytes.push(Number.parseInt(clean.slice(index, index + 2), 16));
  }

  let result = "";
  for (let index = 0; index < bytes.length; index += 3) {
    const first = bytes[index];
    const second = bytes[index + 1];
    const third = bytes[index + 2];

    result += alphabet[first >> 2];
    result += alphabet[((first & 3) << 4) | ((second ?? 0) >> 4)];
    result +=
      second === undefined
        ? "="
        : alphabet[((second & 15) << 2) | ((third ?? 0) >> 6)];
    result += third === undefined ? "=" : alphabet[third & 63];
  }

  return result;
}

function limparJsonMarkdown(texto: string): string {
  return texto
    .replace(/```json\n?/g, "")
    .replace(/```\n?/g, "")
    .trim();
}

function extrairTextoGemini(geminiJson: any): string {
  const parts = geminiJson?.candidates?.[0]?.content?.parts;

  if (Array.isArray(parts)) {
    const text = parts
      .map((part: any) => (typeof part?.text === "string" ? part.text : ""))
      .join("")
      .trim();
    if (text) return text;
  }

  const altText = geminiJson?.candidates?.[0]?.text ?? geminiJson?.text ?? "";
  return typeof altText === "string" ? altText.trim() : "";
}

// ------------------------------------------------------------------
// Leituras on-chain (eth_call: custo zero)
// ------------------------------------------------------------------

function getContractAddress(runtime: Runtime<Config>): `0x${string}` {
  const address = runtime.config.contractAddress;
  if (!/^0x[0-9a-fA-F]{40}$/.test(String(address || ""))) {
    throw new Error(`contractAddress invalido: ${address}`);
  }
  return address;
}

function readNextPendingRequest(runtime: Runtime<Config>): {
  found: boolean;
  requestId: bigint;
  name: string;
} {
  const evmClient = new cre.capabilities.EVMClient(ETHEREUM_SEPOLIA_SELECTOR);

  const callData = encodeFunctionData({
    abi: NEXT_PENDING_REQUEST_ABI,
    functionName: "getNextPendingRequest",
  });

  const response = evmClient
    .callContract(runtime as any, {
      call: encodeCallMsg({
        from: zeroAddress,
        to: getContractAddress(runtime),
        data: callData,
      }),
    })
    .result();

  const [found, requestId, name] = decodeFunctionResult({
    abi: NEXT_PENDING_REQUEST_ABI,
    functionName: "getNextPendingRequest",
    data: bytesToHex((response as any).data),
  });

  return { found, requestId, name };
}

type Candidate = { name: string; score: number };

/**
 * O contrato varre a base inteira e devolve os 10 nomes mais proximos.
 *
 * Mandar so o primeiro colocado era um furo: o ranking posicional erra a
 * ordem. Em "koka kola bebidas", "nota kola refri" ficou em 1o com 63 e
 * "coca cola" — a colisao real — em 2o com 52. Com a lista completa, o
 * score deixa de decidir QUEM vai para a IA; ele so monta os candidatos.
 */
function readTopMatches(
  runtime: Runtime<Config>,
  requestedName: string,
): Candidate[] {
  const evmClient = new cre.capabilities.EVMClient(ETHEREUM_SEPOLIA_SELECTOR);

  const callData = encodeFunctionData({
    abi: TOP_MATCHES_ABI,
    functionName: "topMatches",
    args: [requestedName],
  });

  const response = evmClient
    .callContract(runtime as any, {
      call: encodeCallMsg({
        from: zeroAddress,
        to: getContractAddress(runtime),
        data: callData,
      }),
    })
    .result();

  const decoded = decodeFunctionResult({
    abi: TOP_MATCHES_ABI,
    functionName: "topMatches",
    data: bytesToHex((response as any).data),
  }) as readonly { nome: string; score: bigint }[];

  const candidates: Candidate[] = [];
  for (const item of decoded) {
    const name = String(item?.nome || "");
    const score = Number(item?.score ?? 0);
    if (name.length > 0 && score > 0) {
      candidates.push({ name, score });
    }
  }

  return candidates;
}

// ------------------------------------------------------------------
// Gemini — decisor final
// ------------------------------------------------------------------

/**
 * Prompt reduzido ao minimo de saida.
 *
 * O texto explicativo (fonetica, visual, semantica, sugestoes) continua no
 * frontend, onde nao ha consenso. Aqui os nos do DON precisam devolver a
 * MESMA string, entao a resposta e uma decisao mais, quando recusa, o nome
 * do candidato que colidiu — que vem de uma lista fechada, nao texto livre.
 */
function montarPromptDecisao(
  requestedName: string,
  candidates: Candidate[],
): string {
  const lista =
    candidates.length > 0
      ? candidates
          .map((c) => `  - "${c.name}" (positional score ${c.score})`)
          .join("\n")
      : "  (none registered yet)";

  return `You are a Brazilian trademark examiner (LPI 9.279/96).

Decide whether the REQUESTED mark can be registered, given the list of
already-registered marks below.

CRITERIA:
- Likelihood of confusion or association as to trade origin.
- Phonetic similarity is decisive: spelling changes that do not change
  pronunciation (c/k, s/z, i/y, ph/f) still create collision.
- Judge the overall impression, not a single token.
- A term that is the generic or descriptive name of the product category
  itself (cola, tech, store, cafe, bebidas, digital) cannot be monopolized
  by anyone. Sharing ONLY such a term is NOT collision — competitors are
  free to use it. Collision requires the DISTINCTIVE element to be copied
  or imitated. Compare: "top cola" shares only the generic term with
  "coca cola" and does not collide; "koka kola" reproduces the distinctive
  element phonetically and does collide.
- A word with independent dictionary meaning is more distinctive than a
  coined string that merely shares letters.
- The positional scores are a character-by-character comparison. They are a
  weak signal, frequently wrong, and often rank the wrong candidate first.
  Evaluate EVERY candidate on its own merits. Do not defer to the order.

REQUESTED: "${requestedName}"

REGISTERED CANDIDATES:
${lista}

If ANY candidate collides, answer REJECTED and name that exact candidate,
copied verbatim from the list. If none collides, answer APPROVED.

Answer with JSON only. No markdown, no explanation, no extra keys.
Exactly this shape:
{"decision":"APPROVED","collides_with":""}
or
{"decision":"REJECTED","collides_with":"exact name from the list"}`;
}

/**
 * Devolve "APPROVED|", "REJECTED|<nome>" ou "FAILED|".
 *
 * A string tem que ser identica entre os nos do DON — por isso o resultado
 * vai concatenado numa unica string, e nao num objeto.
 *
 * FAILED cobre API fora do ar, quota estourada, resposta vazia e JSON
 * quebrado. Quem chama decide o que fazer — aqui nao ha decisao silenciosa.
 */
function consultarGemini(
  httpClient: HTTPClient,
  nodeRuntime: any,
  runtime: Runtime<Config>,
  requestedName: string,
  candidates: Candidate[],
): string {
  const apiKey = String(runtime.config.geminiKey || "").trim();
  if (!apiKey) {
    runtime.log("geminiKey vazio no config");
    return "FAILED|";
  }

  const prompt = montarPromptDecisao(requestedName, candidates);

  const response = httpClient
    .sendRequest(nodeRuntime, {
      url:
        `https://generativelanguage.googleapis.com/v1beta/models/` +
        `${GEMINI_MODEL}:generateContent?key=${apiKey}`,
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: encodeBody({
        contents: [{ role: "user", parts: [{ text: prompt }] }],
        generationConfig: {
          // Zero para maximizar a chance dos nos do DON responderem igual.
          temperature: 0,
          maxOutputTokens: 2048,
          responseMimeType: "application/json",
        },
      }),
    } as any)
    .result();

  const statusCode = Number(
    (response as any)?.statusCode ?? (response as any)?.status ?? 200,
  );
  const rawText = bodyToText((response as any)?.body);

  if (statusCode >= 400) {
    runtime.log(`Gemini HTTP ${statusCode}: ${rawText.slice(0, 300)}`);
    return "FAILED|";
  }

  let geminiJson: any;
  try {
    geminiJson = JSON.parse(rawText);
  } catch {
    runtime.log(`Gemini resposta nao era JSON: ${rawText.slice(0, 300)}`);
    return "FAILED|";
  }

  if (geminiJson?.error) {
    runtime.log(`Gemini API error: ${safeStringify(geminiJson.error)}`);
    return "FAILED|";
  }

  const texto = extrairTextoGemini(geminiJson);
  if (!texto) {
    runtime.log("Gemini devolveu texto vazio");
    return "FAILED|";
  }

  runtime.log(`Gemini bruto: ${texto.slice(0, 300)}`);

  try {
    const parsed = JSON.parse(limparJsonMarkdown(texto));
    const decision = String(parsed?.decision || "").trim().toUpperCase();
    const collidesRaw = String(parsed?.collides_with || "").trim();

    if (decision === "APPROVED") {
      return "APPROVED|";
    }

    if (decision === "REJECTED") {
      // O nome tem que existir na lista enviada. Se o modelo inventar ou
      // devolver vazio, a rejeicao vale, mas sem colidente identificado.
      const encontrado = candidates.find(
        (c) => c.name.trim().toLowerCase() === collidesRaw.toLowerCase(),
      );

      if (!encontrado && collidesRaw.length > 0) {
        runtime.log(`Gemini citou candidato fora da lista: "${collidesRaw}"`);
      }

      return `REJECTED|${encontrado ? encontrado.name : ""}`;
    }

    runtime.log(`Gemini devolveu decision inesperada: ${decision}`);
    return "FAILED|";
  } catch {
    runtime.log(`Gemini JSON invalido: ${texto.slice(0, 200)}`);
    return "FAILED|";
  }
}

// ------------------------------------------------------------------
// Escrita do report
// ------------------------------------------------------------------

function sendAnalysisReport(
  runtime: Runtime<Config>,
  requestId: bigint,
  deterministicScore: number,
  matchHash: `0x${string}`,
): string {
  const evmClient = new cre.capabilities.EVMClient(ETHEREUM_SEPOLIA_SELECTOR);

  const encodedAnalysis = encodeAbiParameters(REPORT_PARAMS, [
    requestId,
    deterministicScore,
    matchHash,
    ALGORITHM_VERSION,
  ]);

  const reportData = `0x${REPORT_PREFIX}${encodedAnalysis.slice(2)}`;

  const reportFn = (runtime as any).report;
  if (typeof reportFn !== "function") {
    throw new Error("runtime.report nao existe neste runtime do CRE");
  }

  const signedReport = reportFn
    .call(runtime, {
      encodedPayload: hexToBase64(reportData),
      encoderName: "evm",
      signingAlgo: "ecdsa",
      hashingAlgo: "keccak256",
    })
    .result();

  const writeResult = evmClient
    .writeReport(runtime as any, {
      receiver: getContractAddress(runtime),
      report: signedReport,
      gasConfig: { gasLimit: WRITE_GAS_LIMIT },
    })
    .result();

  const rawTxHash = (writeResult as any)?.txHash;
  const txHash = rawTxHash
    ? typeof rawTxHash === "string"
      ? rawTxHash
      : bytesToHex(rawTxHash)
    : "";

  runtime.log(`txStatus: ${safeStringify((writeResult as any)?.txStatus)}`);
  runtime.log(
    `receiverContractExecutionStatus: ${safeStringify(
      (writeResult as any)?.receiverContractExecutionStatus,
    )}`,
  );
  runtime.log(`errorMessage: ${safeStringify((writeResult as any)?.errorMessage)}`);

  if (!txHash) throw new Error("CRE nao retornou txHash da escrita");
  return txHash;
}

// ------------------------------------------------------------------
// Handler do cron
// ------------------------------------------------------------------

const onCron = (runtime: Runtime<Config>): string => {
  runtime.log("BRANDSCHAIN - TRIAGEM DE MARCA (DECISAO FINAL: GEMINI)");

  const httpClient = new HTTPClient();

  const pending = readNextPendingRequest(runtime);

  if (!pending.found) {
    runtime.log("Nenhuma solicitacao pendente");
    return "SEM_PENDENTES";
  }

  const requestId = pending.requestId;
  const requestedName = pending.name;

  runtime.log(`Solicitacao #${requestId}: "${requestedName}"`);

  const nameBytes = toBytes(requestedName).length;
  if (nameBytes === 0 || nameBytes > MAX_NAME_BYTES) {
    runtime.log(`Nome invalido (${nameBytes} bytes) - rejeitando`);
    return sendAnalysisReport(runtime, requestId, SCORE_REJEICAO, zeroHash);
  }

  // ETAPA 1: o contrato varre a base (view, sem gas) e devolve os 10 mais
  // proximos. A ordem do ranking nao decide nada — a IA avalia todos.
  runtime.log("Consultando topMatches (eth_call, custo zero)...");
  const candidates = readTopMatches(runtime, requestedName);

  if (candidates.length === 0) {
    runtime.log("Base vazia ou sem nenhum candidato — nada com que colidir");
  } else {
    runtime.log(`${candidates.length} candidatos enviados a analise:`);
    for (const c of candidates) {
      runtime.log(`  "${c.name}" (score posicional ${c.score})`);
    }
  }

  // ETAPA 2 (node mode): o Gemini decide.
  // consensusIdenticalAggregation exige que todos os nos devolvam a mesma
  // string. Por isso a saida e minima e o colidente vem de lista fechada.
  const resposta = runtime.runInNodeMode((nodeRuntime: any) => {
    return consultarGemini(
      httpClient,
      nodeRuntime,
      runtime,
      requestedName,
      candidates,
    );
  }, consensusIdenticalAggregation<string>())().result();

  const separador = resposta.indexOf("|");
  const decision = separador >= 0 ? resposta.slice(0, separador) : resposta;
  const collidesWith = separador >= 0 ? resposta.slice(separador + 1) : "";

  runtime.log(`Decisao do Gemini: ${decision}`);
  if (collidesWith) runtime.log(`Colide com: "${collidesWith}"`);

  // ETAPA 3: traduz a decisao para o score que o contrato entende.
  // Rejeitar por engano e reversivel — o usuario solicita de novo.
  // Aprovar por engano grava colisao na blockchain.
  const topScore = candidates.length > 0 ? candidates[0].score : 0;
  let finalScore: number;
  let matchHash: `0x${string}`;

  if (decision === "APPROVED") {
    // O contrato registra quando score < 70. Se o ranking posicional deu
    // acima disso e a IA aprovou mesmo assim, reporta 69 para nao deixar o
    // criterio fraco vetar a decisao boa (caso "ninfa" x "infa": 97).
    finalScore = topScore >= 70 ? 69 : topScore;
    matchHash = zeroHash;

    if (topScore >= 70) {
      runtime.log(
        `Gemini aprovou apesar do score posicional ${topScore}. ` +
        `Reportando 69 para o contrato registrar.`,
      );
    }
  } else if (decision === "REJECTED") {
    finalScore = SCORE_REJEICAO;
    // Grava o hash do colidente apontado pela IA, nao do 1o do ranking —
    // sao frequentemente diferentes.
    matchHash = collidesWith ? keccak256(toBytes(collidesWith)) : zeroHash;
  } else {
    // FAILED: nao registra sem passar pela IA.
    runtime.log("Gemini indisponivel - rejeitando por precaucao");
    finalScore = SCORE_REJEICAO;
    matchHash = zeroHash;
  }

  runtime.log(`Score reportado: ${finalScore}`);
  runtime.log(
    `Veredito on-chain: ${finalScore >= 70 ? "REJEITADA" : "APROVADA"}`,
  );

  // ETAPA 4: unica escrita on-chain
  const txHash = sendAnalysisReport(runtime, requestId, finalScore, matchHash);

  runtime.log(`Estado atualizado on-chain: ${txHash}`);
  return txHash;
};

// ------------------------------------------------------------------
// Bootstrap
// ------------------------------------------------------------------

export const initWorkflow = (config: Config) => {
  const cron = new CronCapability();

  return [
    handler(
      cron.trigger({ schedule: config.schedule || "*/5 * * * *" }) as any,
      onCron,
    ),
  ];
};

export async function main() {
  const runner = await Runner.newRunner<Config>();
  await runner.run(initWorkflow);
}

await main();
