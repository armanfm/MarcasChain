<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1.0"/>
<title>MarcasChain — Registro Descentralizado de Marcas</title>
<script src="https://cdnjs.cloudflare.com/ajax/libs/ethers/6.7.0/ethers.umd.min.js"></script>
<link href="https://fonts.googleapis.com/css2?family=DM+Serif+Display:ital@0;1&family=DM+Mono:wght@400;500&family=DM+Sans:wght@300;400;500;600&display=swap" rel="stylesheet"/>
<style>
:root{
  --bg:#0a0b0d;--surface:#111318;--card:#181c24;--border:#252a36;--border2:#2e3547;
  --gold:#d4a853;--gold2:#f0c97a;--green:#27c17a;--red:#e05252;--amber:#e8973a;
  --blue:#4a7cf7;--text:#e8eaf0;--muted:#6b7491;--muted2:#8892ab;--r:10px;
}
*{margin:0;padding:0;box-sizing:border-box}
body{background:var(--bg);color:var(--text);font-family:'DM Sans',sans-serif;min-height:100vh}
header{position:sticky;top:0;z-index:100;background:rgba(10,11,13,.92);backdrop-filter:blur(16px);border-bottom:1px solid var(--border);padding:0 28px;height:60px;display:flex;align-items:center;justify-content:space-between}
.logo{font-family:'DM Serif Display',serif;font-size:1.25rem}.logo span{color:var(--gold)}
.hright{display:flex;gap:8px;align-items:center}
.badge{font-family:'DM Mono',monospace;font-size:.72rem;background:var(--card);border:1px solid var(--border);padding:5px 10px;border-radius:20px;display:none;color:var(--muted2)}
#bbal{color:var(--green)}
.btn{padding:9px 18px;border:none;border-radius:var(--r);cursor:pointer;font-size:.85rem;font-weight:600;font-family:'DM Sans',sans-serif;transition:all .15s}
.btn-gold{background:linear-gradient(135deg,var(--gold),var(--gold2));color:#0a0b0d}
.btn-gold:hover{opacity:.9;transform:translateY(-1px)}
.btn-ghost{background:transparent;border:1px solid var(--border2);color:var(--text)}
.btn-ghost:hover{border-color:var(--gold);color:var(--gold)}
.btn-sm{padding:6px 12px;font-size:.78rem}
.btn:disabled{opacity:.35;cursor:not-allowed;transform:none!important}
#app{max-width:1080px;margin:0 auto;padding:28px 20px 110px}
#splash{min-height:80vh;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:20px;text-align:center}
.splash-seal{width:80px;height:80px;border:2px solid var(--gold);border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:2rem;box-shadow:0 0 40px rgba(212,168,83,.15)}
#splash h1{font-family:'DM Serif Display',serif;font-size:2.8rem;line-height:1.1}
#splash h1 em{color:var(--gold);font-style:italic}
#splash p{color:var(--muted2);max-width:440px;line-height:1.7}
.splash-meta{display:flex;gap:16px;flex-wrap:wrap;justify-content:center}
.splash-pill{font-size:.75rem;padding:5px 12px;border:1px solid var(--border2);border-radius:20px;color:var(--muted2)}
#setup{display:none}
.setup-box{max-width:620px;margin:60px auto;background:var(--card);border:1px solid var(--border);border-radius:16px;padding:28px}
.setup-title{font-family:'DM Serif Display',serif;font-size:1.4rem;margin-bottom:6px}
.setup-sub{color:var(--muted2);font-size:.84rem;margin-bottom:20px;line-height:1.6}
#main{display:none}
.statbar{display:grid;grid-template-columns:repeat(auto-fit,minmax(120px,1fr));gap:10px;margin-bottom:24px}
.stat{background:var(--card);border:1px solid var(--border);border-radius:var(--r);padding:14px 16px}
.stat-v{font-family:'DM Serif Display',serif;font-size:1.8rem;color:var(--gold)}
.stat-l{font-size:.7rem;color:var(--muted);text-transform:uppercase;letter-spacing:.6px;margin-top:2px}
.tabs{display:flex;gap:4px;margin-bottom:22px;background:var(--surface);padding:5px;border-radius:var(--r);width:fit-content;flex-wrap:wrap}
.tab{padding:8px 20px;border-radius:8px;cursor:pointer;font-size:.85rem;font-weight:500;color:var(--muted2);border:none;background:transparent;transition:all .15s;font-family:'DM Sans',sans-serif}
.tab.on{background:var(--card);color:var(--text);border:1px solid var(--border2);font-weight:600}
.tc{display:none}.tc.on{display:block}
.sec{background:var(--card);border:1px solid var(--border);border-radius:14px;padding:22px;margin-bottom:16px}
.sec-title{font-family:'DM Serif Display',serif;font-size:1.05rem;margin-bottom:4px}
.sec-sub{color:var(--muted2);font-size:.81rem;line-height:1.6;margin-bottom:16px}
.fg{display:flex;flex-direction:column;gap:6px}
.fg label{font-size:.72rem;color:var(--muted);font-weight:600;text-transform:uppercase;letter-spacing:.5px}
.fg input{background:var(--surface);border:1px solid var(--border);color:var(--text);padding:10px 14px;border-radius:8px;font-size:.9rem;font-family:'DM Mono',monospace;outline:none;transition:border .15s}
.fg input:focus{border-color:var(--gold)}
.fg input::placeholder{color:var(--muted);font-family:'DM Sans',sans-serif}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:12px;margin-bottom:14px}
.row{display:flex;gap:10px;flex-wrap:wrap}
.result-panel{background:var(--surface);border:1px solid var(--border);border-radius:12px;padding:20px;margin-top:14px}
.verdict-big{font-family:'DM Serif Display',serif;font-size:1.9rem;line-height:1.2;margin-bottom:6px}
.v-livre{color:var(--green)}
.v-registrada{color:var(--gold)}
.v-pendente{color:var(--amber)}
.v-rejeitada{color:var(--red)}
.verdict-sub{color:var(--muted2);font-size:.86rem;line-height:1.6}
.cells{display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:8px;margin:14px 0 0}
.cell{background:var(--card);border:1px solid var(--border);border-radius:8px;padding:10px 12px}
.cell-l{font-size:.68rem;color:var(--muted);text-transform:uppercase;letter-spacing:.5px;font-weight:600;margin-bottom:3px}
.cell-v{font-size:.85rem;line-height:1.4;word-break:break-word;font-family:'DM Mono',monospace}
.match-row{display:flex;align-items:center;justify-content:space-between;padding:9px 12px;background:var(--card);border-radius:8px;margin-bottom:6px;border:1px solid var(--border);border-left:3px solid var(--border2)}
.match-name{font-family:'DM Mono',monospace;font-size:.86rem}
.match-score{font-family:'DM Mono',monospace;font-size:.8rem;font-weight:700;color:var(--muted2)}
.notice{background:rgba(255,255,255,.02);border:1px dashed var(--border2);border-radius:8px;padding:11px 14px;color:var(--muted2);font-size:.81rem;line-height:1.6}
.alert-err{background:rgba(224,82,82,.06);border:1px solid rgba(224,82,82,.2);border-left:3px solid var(--red);padding:10px 14px;border-radius:8px;font-size:.82rem;color:var(--red)}
.legal{background:rgba(232,151,58,.05);border:1px solid rgba(232,151,58,.2);border-left:3px solid var(--amber);padding:12px 15px;border-radius:8px;font-size:.8rem;line-height:1.65;color:var(--muted2);margin-top:14px}
.legal b{color:var(--amber);font-weight:600}
.brand-card{background:var(--surface);border:1px solid var(--border);border-radius:12px;padding:16px;margin-bottom:10px;transition:border .15s}
.brand-card:hover{border-color:var(--gold)}
.brand-name{font-family:'DM Serif Display',serif;font-size:1.1rem}
.brand-chips{display:flex;gap:6px;flex-wrap:wrap;margin-top:8px}
.chip{font-size:.72rem;padding:3px 9px;border-radius:20px;font-weight:600}
.chip-green{background:rgba(39,193,122,.1);color:var(--green);border:1px solid rgba(39,193,122,.25)}
.chip-amber{background:rgba(232,151,58,.1);color:var(--amber);border:1px solid rgba(232,151,58,.25)}
.chip-gold{background:rgba(212,168,83,.1);color:var(--gold);border:1px solid rgba(212,168,83,.25)}
.chip-red{background:rgba(224,82,82,.1);color:var(--red);border:1px solid rgba(224,82,82,.25)}
.chip-blue{background:rgba(74,124,247,.1);color:var(--blue);border:1px solid rgba(74,124,247,.25)}
.spin{display:inline-block;width:12px;height:12px;border:2px solid var(--border2);border-top-color:var(--gold);border-radius:50%;animation:sp .7s linear infinite;vertical-align:-1px;margin-right:7px}
@keyframes sp{to{transform:rotate(360deg)}}
#statusbar{position:fixed;bottom:0;left:0;right:0;background:rgba(17,19,24,.96);backdrop-filter:blur(12px);border-top:1px solid var(--border);padding:9px 24px;display:flex;align-items:center;gap:12px;z-index:200;min-height:44px}
.sbl{font-size:.68rem;text-transform:uppercase;font-weight:700;color:var(--muted);letter-spacing:.6px;white-space:nowrap}
#sbm{flex:1;overflow-x:auto;display:flex;gap:6px;scrollbar-width:none}
.sbe{font-size:.76rem;white-space:nowrap;padding:3px 10px;border-radius:20px;animation:fi .25s}
.sbe-i{background:rgba(74,124,247,.12);color:var(--blue)}
.sbe-s{background:rgba(39,193,122,.12);color:var(--green)}
.sbe-e{background:rgba(224,82,82,.12);color:var(--red)}
.sbe-p{background:rgba(212,168,83,.12);color:var(--gold)}
@keyframes fi{from{opacity:0;transform:translateY(3px)}to{opacity:1}}
#toast-c{position:fixed;top:70px;right:16px;display:flex;flex-direction:column;gap:8px;z-index:300}
.toast{background:var(--card);border:1px solid var(--border);border-radius:12px;padding:12px 15px;font-size:.82rem;max-width:320px;display:flex;align-items:flex-start;gap:10px;animation:ts .2s}
.toast.ts{border-color:var(--green)}.toast.te{border-color:var(--red)}.toast.tp{border-color:var(--gold)}
.toast-ico{flex-shrink:0}.toast-title{font-weight:700;font-size:.74rem;text-transform:uppercase;margin-bottom:2px}
.empty{text-align:center;padding:32px;color:var(--muted);font-size:.85rem}
.empty-ico{font-size:2.4rem;margin-bottom:8px}
.step{display:flex;gap:14px;align-items:flex-start;margin-bottom:16px}
.step-n{flex-shrink:0;width:28px;height:28px;border-radius:50%;border:1px solid var(--gold);color:var(--gold);display:flex;align-items:center;justify-content:center;font-family:'DM Mono',monospace;font-size:.8rem;font-weight:500}
.step-t{font-weight:600;font-size:.92rem;margin-bottom:4px}
.step-d{color:var(--muted2);font-size:.84rem;line-height:1.65}
.prompt{background:var(--surface);border:1px solid var(--border);border-radius:10px;padding:16px;font-family:'DM Mono',monospace;font-size:.76rem;line-height:1.6;color:var(--muted2);white-space:pre-wrap;overflow-x:auto}
@keyframes ts{from{opacity:0;transform:translateX(24px)}to{opacity:1}}
@media(max-width:680px){#splash h1{font-size:2rem}.tabs{width:100%}}
@media(prefers-reduced-motion:reduce){*{animation:none!important;transition:none!important}}
</style>
</head>
<body>
<header>
  <div class="logo">Marcas<span>Chain</span></div>
  <div class="hright">
    <span class="badge" id="bnet"></span>
    <span class="badge" id="bbal"></span>
    <span class="badge" id="bwallet"></span>
  </div>
</header>
<div id="toast-c"></div>
<div id="app">

<!-- SPLASH -->
<section id="splash">
  <div class="splash-seal">⚖️</div>
  <h1>Registro Descentralizado<br>de <em>Marcas</em></h1>
  <p>Triagem de similaridade feita fora da blockchain e um veredito gravado on-chain. Você paga apenas o gas da solicitação.</p>
  <div class="splash-meta">
    <span class="splash-pill">🔍 Análise off-chain</span>
    <span class="splash-pill">🤖 Triagem por IA</span>
    <span class="splash-pill">⛓ Veredito on-chain</span>
    <span class="splash-pill">⛽ Custo fixo</span>
  </div>
  <button class="btn btn-gold" style="font-size:.95rem;padding:12px 32px;margin-top:8px" onclick="conectar()">Conectar MetaMask</button>
</section>

<!-- SETUP -->
<section id="setup">
  <div class="setup-box">
    <div class="setup-title">Endereço do contrato</div>
    <div class="setup-sub">Cole o endereço do contrato Marcas implantado na Sepolia.</div>
    <div class="grid">
      <div class="fg"><label>Marcas.sol</label><input id="a-marcas" spellcheck="false" placeholder="0x..."/></div>
    </div>
    <div id="setup-err" class="alert-err" style="display:none;margin-bottom:12px"></div>
    <button class="btn btn-gold" onclick="ligar()">Entrar</button>
  </div>
</section>

<!-- MAIN -->
<main id="main">
  <div class="statbar">
    <div class="stat"><div class="stat-v" id="st-marcas">—</div><div class="stat-l">Marcas registradas</div></div>
    <div class="stat"><div class="stat-v" id="st-fila">—</div><div class="stat-l">Na fila de análise</div></div>
    <div class="stat"><div class="stat-v" id="st-minhas">—</div><div class="stat-l">Minhas marcas</div></div>
  </div>

  <div class="tabs">
    <button class="tab on" onclick="tab('consultar')">🔍 Consultar</button>
    <button class="tab" onclick="tab('solicitar')">📋 Solicitar registro</button>
    <button class="tab" onclick="tab('painel')">📁 Meu painel</button>
    <button class="tab" onclick="tab('base')">📚 Base registrada</button>
    <button class="tab" onclick="tab('como')">⚙️ Como funciona</button>
  </div>

  <!-- CONSULTAR -->
  <div id="tp-consultar" class="tc on">
    <div class="sec">
      <div class="sec-title">Consultar uma marca</div>
      <div class="sec-sub">Mostra a situação do nome nesta base: livre, na fila de análise, registrado ou recusado.</div>
      <div class="row" style="margin-bottom:10px">
        <div class="fg" style="flex:1;min-width:220px"><label>Nome da marca</label><input id="q-nome" placeholder="Ex: Meola" onkeydown="if(event.key==='Enter')consultar()"/></div>
        <div style="display:flex;align-items:flex-end"><button class="btn btn-gold" onclick="consultar()">Consultar</button></div>
      </div>
      <div id="c-result" style="display:none"></div>
    </div>
  </div>

  <!-- SOLICITAR -->
  <div id="tp-solicitar" class="tc">
    <div class="sec">
      <div class="sec-title">Solicitar registro</div>
      <div class="sec-sub">Sua solicitação entra numa fila. A análise roda fora da blockchain e o veredito é gravado automaticamente — normalmente em poucos minutos.</div>
      <div class="grid">
        <div class="fg"><label>Nome da marca</label><input id="r-nome" placeholder="nome da sua marca" onkeydown="if(event.key==='Enter')verificar()"/></div>
      </div>
      <div id="r-check" style="margin-bottom:14px"></div>
      <div id="r-err" class="alert-err" style="display:none;margin-bottom:10px"></div>
      <div class="row">
        <button class="btn btn-ghost" onclick="verificar()">Ver prévia</button>
        <button class="btn btn-gold" id="btn-solicitar" onclick="solicitar()">Solicitar registro</button>
      </div>
      <div class="legal">
        <b>Aviso.</b> Esta é uma triagem automatizada de similaridade e não substitui orientação jurídica. Ela não consulta a base do INPI, não avalia classe de produtos e serviços nem uso comercial anterior. Antes de investir na marca ou depositar um pedido, <b>consulte um advogado ou agente da propriedade industrial</b>.
      </div>
    </div>

    <div class="sec" id="acomp-sec" style="display:none">
      <div class="sec-title">Acompanhando sua solicitação</div>
      <div class="sec-sub">Esta tela se atualiza sozinha a cada 20 segundos.</div>
      <div id="acomp-body"></div>
    </div>
  </div>

  <!-- PAINEL -->
  <div id="tp-painel" class="tc">
    <div class="sec">
      <div class="sec-title">Minhas solicitações</div>
      <div class="sec-sub">Tudo que você já enviou com esta carteira.</div>
      <div id="painel-lista"><div class="empty"><div class="empty-ico">📋</div>Nenhuma solicitação encontrada.</div></div>
    </div>
  </div>

  <!-- BASE -->
  <div id="tp-base" class="tc">
    <div class="sec">
      <div class="sec-title">Marcas registradas</div>
      <div class="sec-sub">Todos os nomes que passaram na triagem.</div>
      <div id="base-lista"><div class="empty"><div class="empty-ico">📚</div>Carregando…</div></div>
    </div>
  </div>

  <!-- COMO FUNCIONA -->
  <div id="tp-como" class="tc">
    <div class="sec">
      <div class="sec-title">O que acontece depois que você solicita</div>
      <div class="sec-sub">A análise tem duas etapas, e a segunda é quem decide.</div>

      <div class="step">
        <div class="step-n">1</div>
        <div>
          <div class="step-t">O contrato encontra o nome mais parecido</div>
          <div class="step-d">Uma função de leitura percorre todas as marcas registradas e compara caractere por caractere, devolvendo apenas o nome que mais se aproxima e uma nota de 0 a 100. Como é leitura, essa varredura não custa gas — é por isso que o registro tem preço fixo por mais que a base cresça.</div>
        </div>
      </div>

      <div class="step">
        <div class="step-n">2</div>
        <div>
          <div class="step-t">Uma IA analisa esse par e decide</div>
          <div class="step-d">A nota do passo anterior é só um sinal de apoio. Quem decide é um modelo de linguagem, que avalia o nome solicitado contra o nome mais próximo considerando pronúncia, sentido e força distintiva. A decisão volta assinada por um oráculo descentralizado e é gravada no contrato.</div>
        </div>
      </div>

      <div class="notice" style="margin-top:16px">Se a IA estiver indisponível, a solicitação é recusada por precaução — nada entra no registro sem passar pela análise. Você pode solicitar de novo depois.</div>
    </div>

    <div class="sec">
      <div class="sec-title">Por que a nota sozinha não basta</div>
      <div class="sec-sub">A comparação de caracteres erra nos dois sentidos. Dois casos reais deste sistema:</div>

      <div class="cells" style="margin-top:0">
        <div class="cell" style="border-left:3px solid var(--red)">
          <div class="cell-l">Nota baixa, mas colide</div>
          <div class="cell-v" style="font-family:'DM Sans',sans-serif;line-height:1.6;font-size:.84rem">
            <b style="font-family:'DM Mono',monospace">koka kola refrigerante</b> contra <b style="font-family:'DM Mono',monospace">coca cola</b> tirou <b>43</b> — abaixo do limite, seria aprovada. Mas <i>k</i> soa igual a <i>c</i>: é a mesma marca escrita de outro jeito. A IA recusou.
          </div>
        </div>
        <div class="cell" style="border-left:3px solid var(--green)">
          <div class="cell-l">Nota alta, mas não colide</div>
          <div class="cell-v" style="font-family:'DM Sans',sans-serif;line-height:1.6;font-size:.84rem">
            <b style="font-family:'DM Mono',monospace">ninfa</b> contra <b style="font-family:'DM Mono',monospace">infa</b> tirou <b>97</b> — seria recusada. Mas "ninfa" é palavra de dicionário, com sentido próprio. Quatro letras em sequência não fazem delas a mesma marca.
          </div>
        </div>
      </div>
    </div>

    <div class="sec">
      <div class="sec-title">O critério usado pela IA</div>
      <div class="sec-sub">Estas são as instruções exatas enviadas ao modelo a cada análise. Publicamos para que o critério seja verificável.</div>
      <pre class="prompt">You are a Brazilian trademark examiner (LPI 9.279/96).

Decide whether the REQUESTED mark can be registered, given the closest
already-registered mark.

CRITERIA:
- Likelihood of confusion or association as to trade origin.
- Phonetic similarity is decisive: spelling changes that do not change
  pronunciation (c/k, s/z, i/y, ph/f) still create collision.
- Judge the overall impression, not a single token.
- Generic or descriptive terms add little distinctiveness.
- A word with independent dictionary meaning is more distinctive than a
  coined string that merely shares letters.
- The numeric score is a positional character comparison only. It is a weak
  signal and is often wrong. Do not defer to it.

REQUESTED: "{nome solicitado}"
CLOSEST REGISTERED: "{nome mais parecido}"
POSITIONAL SCORE: {nota}/100

Answer with JSON only. No markdown, no explanation, no extra keys.</pre>
      <div class="notice" style="margin-top:12px">O modelo responde apenas <span style="font-family:'DM Mono',monospace">{"decision":"APPROVED"}</span> ou <span style="font-family:'DM Mono',monospace">{"decision":"REJECTED"}</span>. A resposta precisa ser idêntica entre os nós do oráculo para haver consenso — por isso a saída é mínima e a explicação não é gravada.</div>
      <div class="legal"><b>Aviso.</b> Este é um critério de triagem, não uma análise jurídica. Não considera classe de produtos e serviços, uso comercial anterior nem marca notoriamente conhecida, e não consulta a base do INPI. <b>Consulte um advogado ou agente da propriedade industrial</b> antes de decidir sobre a marca.</div>
    </div>
  </div>

</main>
</div>

<div id="statusbar">
  <span class="sbl">Status</span>
  <div id="sbm"><span class="sbe sbe-i">Aguardando conexão…</span></div>
</div>

<script>
"use strict";

/* ── ABI do contrato Marcas (versão CRE, sem NFT) ── */
const ABI_MARCAS = [
  "function owner() view returns (address)",
  "function creForwarder() view returns (address)",
  "function totalMarcas() view returns (uint256)",
  "function totalSolicitacoes() view returns (uint256)",
  "function proximaPendente() view returns (uint256)",
  "function LIMITE_REJEICAO() view returns (uint256)",
  "function analisar(string) view returns (uint256 score,string decision,string risk,string matchCom)",
  "function analisarParaCRE(string) view returns (uint256 score,bytes32 matchHash,string matchNome)",
  "function topMatches(string) view returns (tuple(string nome,uint256 score)[10])",
  "function podeSolicitar(string) view returns (bool,string)",
  "function solicitarRegistro(string) returns (uint256)",
  "function getNextPendingRequest() view returns (bool found,uint256 requestId,string nome)",
  "function getSolicitacao(uint256) view returns (tuple(string nome,address solicitante,uint256 criadaEm,uint256 processadaEm,uint256 score,bytes32 matchHash,uint32 algorithmVersion,uint8 status))",
  "function getMarca(string) view returns (string,address,uint256,uint256)",
  "function getMarcasPorPagina(uint256,uint256) view returns (string[])",
  "function temSolicitacaoAberta(bytes32) view returns (bool)",
  "function transferir(string,address)",
  "event RegistroSolicitado(uint256 indexed requestId,string nome,address indexed solicitante)",
  "event SolicitacaoProcessada(uint256 indexed requestId,uint8 status,uint256 score,bytes32 matchHash)",
  "event MarcaRegistrada(string indexed nome,address indexed dono,uint256 score)"
];

const STATUS_TXT = {
  0:"NENHUMA", 1:"PENDENTE", 2:"APROVADA", 3:"REJEITADA", 4:"INVALIDA"
};

const SK = "mc_cre_v1";
let prov, signer, me = "";
let CM = null;
let ST = { total:0, fila:0, owner:"", forwarder:"" };
let acompTimer = null;

/* ── Utils ── */
const H = v => String(v??"").replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;");
const sh = a => (!a||a===ethers.ZeroAddress)?"—":a.slice(0,6)+"…"+a.slice(-4);
const fe = w => { try{return Number(ethers.formatEther(w)).toFixed(4)}catch{return"0"} };
const fdt = t => (!t||Number(t)===0)?"—":new Date(Number(t)*1000).toLocaleString("pt-BR",{day:"2-digit",month:"short",hour:"2-digit",minute:"2-digit"});
const sc = async(fn,fb) => { try{return await fn()}catch{return fb} };

function fe2(e){
  if(!e)return"Erro desconhecido";
  if(String(e.code)==="4001")return"Transação recusada no MetaMask.";
  const r=e.shortMessage||e.reason||e.info?.error?.message||e.data?.message||e.message||String(e);
  return String(r).replace(/^execution reverted:\s*/i,"").replace(/^Error:\s*/i,"").trim();
}

function lg(m,t="i"){
  const b=document.getElementById("sbm");
  const el=document.createElement("span");
  el.className="sbe sbe-"+({i:"i",s:"s",e:"e",p:"p"}[t]||"i");
  el.textContent=m;b.insertBefore(el,b.firstChild);
  while(b.children.length>8)b.removeChild(b.lastChild);
}

function toast(title,msg,type="i"){
  const icons={i:"ℹ️",s:"✅",e:"❌",p:"⏳"};
  const map={s:"ts",e:"te",p:"tp"};
  const c=document.getElementById("toast-c");
  const el=document.createElement("div");
  el.className="toast "+(map[type]||"");
  el.innerHTML=`<span class="toast-ico">${icons[type]||"ℹ️"}</span><div><div class="toast-title">${H(title)}</div><div style="color:var(--muted2);font-size:.8rem">${H(msg)}</div></div>`;
  c.appendChild(el);setTimeout(()=>el.remove(),5200);
}

/* ── Conexão ── */
async function conectar(){
  if(!window.ethereum){toast("MetaMask não encontrada","Instale a extensão para continuar.","e");return;}
  try{
    await window.ethereum.request({method:"eth_requestAccounts"});
    prov=new ethers.BrowserProvider(window.ethereum);
    signer=await prov.getSigner();
    me=await signer.getAddress();
    const chain=await prov.getNetwork();
    document.getElementById("bnet").textContent=chain.name;
    document.getElementById("bnet").style.display="inline";
    document.getElementById("bwallet").textContent=sh(me);
    document.getElementById("bwallet").style.display="inline";
    const bal=await prov.getBalance(me);
    document.getElementById("bbal").textContent=fe(bal)+" ETH";
    document.getElementById("bbal").style.display="inline";
    lg("Conectado: "+sh(me),"s");
    document.getElementById("splash").style.display="none";
    document.getElementById("setup").style.display="block";
    const saved=JSON.parse(localStorage.getItem(SK)||"{}");
    document.getElementById("a-marcas").value=saved.marcas||"";
    window.ethereum.on("accountsChanged",()=>location.reload());
    window.ethereum.on("chainChanged",()=>location.reload());
  }catch(e){lg("Erro: "+fe2(e),"e");toast("Não foi possível conectar",fe2(e),"e");}
}

async function ligar(){
  const eb=document.getElementById("setup-err");eb.style.display="none";
  try{
    const am=document.getElementById("a-marcas").value.trim();
    if(!am)throw new Error("Cole o endereço do contrato.");
    if(!ethers.isAddress(am))throw new Error("Endereço inválido.");
    const code=await prov.getCode(am);
    if(code==="0x")throw new Error("Não há contrato neste endereço nesta rede.");
    CM=new ethers.Contract(ethers.getAddress(am),ABI_MARCAS,signer);
    await CM.totalMarcas();
    localStorage.setItem(SK,JSON.stringify({marcas:am}));
    document.getElementById("setup").style.display="none";
    document.getElementById("main").style.display="block";
    await refresh();
    lg("Contrato conectado","s");
  }catch(e){eb.textContent=fe2(e);eb.style.display="block";lg("Erro: "+fe2(e),"e");}
}

/* ── Estado ── */
async function refresh(){
  const [tm,ts,fw]=await Promise.all([
    sc(()=>CM.totalMarcas(),0n),
    sc(()=>CM.totalSolicitacoes(),0n),
    sc(()=>CM.creForwarder(),ethers.ZeroAddress),
  ]);
  ST.total=Number(tm);ST.forwarder=fw;
  document.getElementById("st-marcas").textContent=ST.total;

  // fila = solicitações ainda pendentes
  let fila=0;
  const total=Number(ts);
  const inicio=Math.max(0,total-40); // só as 40 mais recentes, para não pesar
  for(let i=inicio;i<total;i++){
    const s=await sc(()=>CM.getSolicitacao(i),null);
    if(s&&Number(s.status)===1)fila++;
  }
  ST.fila=fila;
  document.getElementById("st-fila").textContent=fila;

  const bal=await prov.getBalance(me);
  document.getElementById("bbal").textContent=fe(bal)+" ETH";

  if(ST.forwarder===ethers.ZeroAddress){
    lg("Atenção: creForwarder não configurado","e");
  }
}

/* ── Busca a última solicitação de um nome ── */
async function buscarSolicitacaoPorNome(nome){
  const alvo=nome.trim().toLowerCase();
  try{
    const lb=await prov.getBlockNumber();
    const fb=Math.max(0,lb-50000);
    const evs=await CM.queryFilter(CM.filters.RegistroSolicitado(),fb,lb);
    const match=evs.filter(e=>String(e.args?.nome||"").trim().toLowerCase()===alvo);
    if(!match.length)return null;
    const ultimo=match[match.length-1];
    const id=Number(ultimo.args.requestId);
    const s=await CM.getSolicitacao(id);
    return {requestId:id,sol:s};
  }catch(e){return null;}
}

/* ── CONSULTAR ── */
async function consultar(){
  const nome=document.getElementById("q-nome").value.trim();
  const box=document.getElementById("c-result");
  if(!nome){toast("Digite um nome","Informe a marca que quer consultar.","e");return;}

  box.style.display="block";
  box.innerHTML=`<div class="result-panel"><span class="spin"></span>Consultando…</div>`;
  lg("Consultando: "+nome,"p");

  try{
    const [marca,analise,top,encontrado]=await Promise.all([
      sc(()=>CM.getMarca(nome),null),
      sc(()=>CM.analisar(nome),null),
      sc(()=>CM.topMatches(nome),[]),
      buscarSolicitacaoPorNome(nome),
    ]);

    const registrada = marca && marca[0] !== "" && Number(marca[2])>0;
    let titulo, classe, sub, extra="";

    if(registrada){
      titulo="Registrada";
      classe="v-registrada";
      sub=`Este nome já pertence a ${sh(marca[1])}. Não é possível solicitar.`;
      extra=`<div class="cells">
        <div class="cell"><div class="cell-l">Titular</div><div class="cell-v">${H(sh(marca[1]))}${marca[1].toLowerCase()===me.toLowerCase()?" (você)":""}</div></div>
        <div class="cell"><div class="cell-l">Registrada em</div><div class="cell-v">${fdt(marca[2])}</div></div>
        <div class="cell"><div class="cell-l">Score na aprovação</div><div class="cell-v">${Number(marca[3])}</div></div>
      </div>`;
    } else if(encontrado && Number(encontrado.sol.status)===1){
      titulo="Na fila de análise";
      classe="v-pendente";
      sub="Alguém já pediu este nome e a análise ainda não terminou. Consulte de novo em alguns minutos.";
      extra=`<div class="cells">
        <div class="cell"><div class="cell-l">Solicitação</div><div class="cell-v">#${encontrado.requestId}</div></div>
        <div class="cell"><div class="cell-l">Enviada em</div><div class="cell-v">${fdt(encontrado.sol.criadaEm)}</div></div>
      </div>`;
    } else if(encontrado && Number(encontrado.sol.status)===3){
      titulo="Recusada na triagem";
      classe="v-rejeitada";
      sub="Este nome foi analisado e recusado por semelhança com uma marca já registrada. Você pode solicitar de novo, mas o resultado tende a se repetir.";
      extra=`<div class="cells">
        <div class="cell"><div class="cell-l">Solicitação</div><div class="cell-v">#${encontrado.requestId}</div></div>
        <div class="cell"><div class="cell-l">Analisada em</div><div class="cell-v">${fdt(encontrado.sol.processadaEm)}</div></div>
      </div>`;
    } else {
      titulo="Livre nesta base";
      classe="v-livre";
      sub="Nenhum registro nem solicitação em aberto com este nome. Ele ainda passa pela triagem quando você solicitar.";
    }

    let matchesHtml="";
    const filtrados=(top||[]).filter(m=>m.nome&&Number(m.score)>0);
    if(filtrados.length){
      matchesHtml=`<div style="margin-top:18px">
        <div class="cell-l" style="margin-bottom:8px">Nomes parecidos já registrados</div>
        ${filtrados.map(m=>`<div class="match-row"><span class="match-name">${H(m.nome)}</span><span class="match-score">${Number(m.score)}</span></div>`).join("")}
        <div class="notice" style="margin-top:8px">Este número é só uma comparação de caracteres. A decisão final considera pronúncia e sentido, e pode ser diferente.</div>
      </div>`;
    }

    box.innerHTML=`<div class="result-panel">
      <div class="verdict-big ${classe}">${titulo}</div>
      <div class="verdict-sub">${H(sub)}</div>
      ${extra}
      ${matchesHtml}
      <div class="legal"><b>Aviso.</b> Triagem automatizada de similaridade. Não consulta o INPI e não substitui orientação jurídica. <b>Consulte um advogado ou agente da propriedade industrial</b> antes de tomar decisões sobre a marca.</div>
    </div>`;

    lg("Consulta: "+titulo,"s");
  }catch(e){
    box.innerHTML=`<div class="alert-err">${H(fe2(e))}</div>`;
    lg("Erro: "+fe2(e),"e");
  }
}

/* ── SOLICITAR ── */
async function verificar(){
  const nome=document.getElementById("r-nome").value.trim();
  const box=document.getElementById("r-check");
  document.getElementById("r-err").style.display="none";

  if(!nome){box.innerHTML="";toast("Digite um nome","Informe a marca que quer registrar.","e");return;}

  box.innerHTML=`<div class="notice"><span class="spin"></span>Consultando…</div>`;

  try{
    const analise=await sc(()=>CM.analisar(nome),null);
    const score=analise?Number(analise[0]):null;
    const match=analise?analise[3]:"";

    box.innerHTML=`${score!==null?`<div class="cells" style="margin-top:0">
      <div class="cell"><div class="cell-l">Nome mais parecido</div><div class="cell-v">${H(match||"nenhum")}</div></div>
      <div class="cell"><div class="cell-l">Similaridade de caracteres</div><div class="cell-v">${score}</div></div>
    </div>
    <div class="notice" style="margin-top:8px">Esta é só a comparação de caracteres — um sinal fraco. Quem decide é a análise por IA, que considera pronúncia e sentido e pode chegar a outra conclusão em qualquer direção. Veja a aba <b>Como funciona</b>.</div>`:""}`;

    lg("Prévia: "+(match||"sem match")+" ("+score+")","i");
  }catch(e){
    box.innerHTML="";
    document.getElementById("r-err").textContent=fe2(e);
    document.getElementById("r-err").style.display="block";
  }
}

async function solicitar(){
  const nome=document.getElementById("r-nome").value.trim();
  if(!nome)return;

  lg("Enviando solicitação…","p");
  toast("MetaMask","Confirme a transação.","p");

  try{
    const t=await CM.solicitarRegistro(nome);
    lg("Transação enviada","p");
    const rec=await t.wait();

    let requestId=null;
    for(const log of rec.logs){
      try{
        const parsed=CM.interface.parseLog(log);
        if(parsed && parsed.name==="RegistroSolicitado"){
          requestId=Number(parsed.args.requestId);
          break;
        }
      }catch{}
    }

    lg("Solicitação #"+requestId+" criada","s");
    toast("Solicitação enviada",`#${requestId} — a análise começa em instantes.`,"s");
    document.getElementById("btn-solicitar").disabled=true;
    document.getElementById("r-check").innerHTML="";

    if(requestId!==null) acompanhar(requestId);
    await refresh();
  }catch(e){
    const m=fe2(e);
    document.getElementById("r-err").textContent=m;
    document.getElementById("r-err").style.display="block";
    lg("Erro: "+m,"e");
    toast("Não foi possível solicitar",m,"e");
  }
}

/* ── ACOMPANHAMENTO ── */
function acompanhar(requestId){
  const sec=document.getElementById("acomp-sec");
  sec.style.display="block";
  sec.scrollIntoView({behavior:"smooth",block:"nearest"});
  if(acompTimer) clearInterval(acompTimer);
  pintarAcomp(requestId);
  acompTimer=setInterval(()=>pintarAcomp(requestId),20000);
}

async function pintarAcomp(requestId){
  const body=document.getElementById("acomp-body");
  try{
    const s=await CM.getSolicitacao(requestId);
    const st=Number(s.status);

    if(st===1){
      const espera=Math.max(0,Math.floor(Date.now()/1000)-Number(s.criadaEm));
      body.innerHTML=`<div class="result-panel">
        <div class="verdict-big v-pendente"><span class="spin"></span>Em análise</div>
        <div class="verdict-sub">Solicitação #${requestId} — "${H(s.nome)}". Aguardando há ${Math.floor(espera/60)} min ${espera%60} s.</div>
        <div class="notice" style="margin-top:12px">A triagem roda fora da blockchain em ciclos de poucos minutos. Você pode fechar esta página: o resultado fica gravado no contrato.</div>
      </div>`;
      return;
    }

    if(acompTimer){clearInterval(acompTimer);acompTimer=null;}

    if(st===2){
      body.innerHTML=`<div class="result-panel">
        <div class="verdict-big v-livre">Registrada</div>
        <div class="verdict-sub">"${H(s.nome)}" passou na triagem e agora está no seu nome.</div>
        <div class="cells">
          <div class="cell"><div class="cell-l">Score final</div><div class="cell-v">${Number(s.score)}</div></div>
          <div class="cell"><div class="cell-l">Analisada em</div><div class="cell-v">${fdt(s.processadaEm)}</div></div>
        </div>
      </div>`;
      toast("Marca registrada",s.nome,"s");
    } else if(st===3){
      body.innerHTML=`<div class="result-panel">
        <div class="verdict-big v-rejeitada">Recusada</div>
        <div class="verdict-sub">"${H(s.nome)}" foi recusada por semelhança com uma marca já registrada.</div>
        <div class="cells">
          <div class="cell"><div class="cell-l">Analisada em</div><div class="cell-v">${fdt(s.processadaEm)}</div></div>
        </div>
        <div class="legal"><b>Aviso.</b> A recusa vale apenas para esta base e não representa decisão do INPI. Para entender suas opções, <b>consulte um advogado ou agente da propriedade industrial</b>.</div>
      </div>`;
      toast("Marca recusada",s.nome,"e");
    } else {
      body.innerHTML=`<div class="result-panel">
        <div class="verdict-big v-pendente">Não concluída</div>
        <div class="verdict-sub">A solicitação #${requestId} foi encerrada sem veredito. Você pode solicitar novamente.</div>
      </div>`;
    }
    await refresh();
  }catch(e){
    body.innerHTML=`<div class="alert-err">${H(fe2(e))}</div>`;
  }
}

/* ── PAINEL ── */
async function renderPainel(){
  const el=document.getElementById("painel-lista");
  el.innerHTML=`<div class="empty"><span class="spin"></span>Carregando…</div>`;
  try{
    const lb=await prov.getBlockNumber();
    const fb=Math.max(0,lb-50000);
    const evs=await CM.queryFilter(CM.filters.RegistroSolicitado(null,me),fb,lb);

    if(!evs.length){
      document.getElementById("st-minhas").textContent="0";
      el.innerHTML=`<div class="empty"><div class="empty-ico">📋</div>Você ainda não solicitou nenhuma marca.</div>`;
      return;
    }

    const cards=await Promise.all(evs.slice().reverse().map(async ev=>{
      const id=Number(ev.args.requestId);
      const s=await sc(()=>CM.getSolicitacao(id),null);
      if(!s)return "";
      const st=Number(s.status);
      const chip={1:"chip-amber",2:"chip-green",3:"chip-red",4:"chip-blue"}[st]||"chip-blue";
      const txt={1:"EM ANÁLISE",2:"REGISTRADA",3:"RECUSADA",4:"ENCERRADA"}[st]||"—";
      return `<div class="brand-card">
        <div class="brand-name">${H(s.nome)}</div>
        <div class="brand-chips">
          <span class="chip ${chip}">${txt}</span>
          <span class="chip chip-gold">#${id}</span>
          ${st!==1?`<span class="chip chip-blue">score ${Number(s.score)}</span>`:""}
        </div>
        <div style="margin-top:8px;font-size:.76rem;color:var(--muted)">Enviada em ${fdt(s.criadaEm)}</div>
        ${st===1?`<div style="margin-top:10px"><button class="btn btn-ghost btn-sm" onclick="tab('solicitar');acompanhar(${id})">Acompanhar</button></div>`:""}
      </div>`;
    }));

    const registradas=cards.filter(c=>c.includes("REGISTRADA")).length;
    document.getElementById("st-minhas").textContent=registradas;
    el.innerHTML=cards.join("");
  }catch(e){
    el.innerHTML=`<div class="empty">${H(fe2(e))}</div>`;
  }
}

/* ── BASE ── */
async function renderBase(){
  const el=document.getElementById("base-lista");
  el.innerHTML=`<div class="empty"><span class="spin"></span>Carregando…</div>`;
  try{
    const total=Number(await CM.totalMarcas());
    if(!total){
      el.innerHTML=`<div class="empty"><div class="empty-ico">📚</div>Nenhuma marca registrada ainda.</div>`;
      return;
    }
    const nomes=[];
    for(let off=0;off<total;off+=25){
      const page=await CM.getMarcasPorPagina(off,Math.min(25,total-off));
      nomes.push(...page);
    }
    el.innerHTML=nomes.map(n=>`<div class="brand-card"><div class="brand-name">${H(n)}</div></div>`).join("");
  }catch(e){
    el.innerHTML=`<div class="empty">${H(fe2(e))}</div>`;
  }
}

/* ── TABS ── */
function tab(n){
  const ns=["consultar","solicitar","painel","base"];
  document.querySelectorAll(".tab").forEach((t,i)=>t.classList.toggle("on",ns[i]===n));
  document.querySelectorAll(".tc").forEach(c=>c.classList.remove("on"));
  document.getElementById("tp-"+n).classList.add("on");
  if(n==="painel") renderPainel();
  if(n==="base") renderBase();
}
</script>
</body>
</html>
