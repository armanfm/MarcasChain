# 🗺️ Roadmap — MarcasChain

## ✅ Fase 1 — Protocolo Base (Concluído)

Sistema descentralizado de registro de marcas com análise de similaridade on-chain e proteção via NFT.

- [x] Motor de similaridade on-chain (score 0–100)
- [x] Normalização de texto, inversão, splitWords e combinação de palavras
- [x] Decisão automática por score (aprovado / rejeitado)
- [x] Registro de marca gratuito (paga só gas)
- [x] NFT ERC-721 com 10 anos de proteção
- [x] Renovação de proteção por ETH
- [x] Expiração automática por timestamp
- [x] Liberação de marca expirada por qualquer usuário
- [x] Transferência de registro entre carteiras
- [x] Frontend completo com conexão MetaMask
- [x] Revisão semântica via Gemini (fonética, visual, semântica)
- [x] Sugestões automáticas de variações aprovadas
- [x] Deploy na Sepolia Testnet

---

## 🔄 Fase 2 — Análise Verificável On-Chain (Em desenvolvimento)

Integração com Chainlink CRE e IPFS para tornar a análise semântica permanente, verificável e obrigatória no fluxo de registro.

- [ ] Campo `cid` no struct de registro (`Marcas.sol`)
- [ ] Análise de similaridade filtrando apenas marcas com CID — marcas sem CID não entram no match
- [ ] Integração com Chainlink Runtime Environment (CRE)
- [ ] Workflow CRE em TypeScript: análise via Gemini → salva no IPFS → grava CID on-chain
- [ ] Cache por CID — marca já analisada nunca aciona o oracle novamente
- [ ] Mint automático pelo CRE após gravação do CID
- [ ] CID como requisito obrigatório para mint — sem análise semântica, sem proteção
- [ ] Resultado da análise permanente e público via `ipfs.io/ipfs/{CID}`
- [ ] `MarcasNFT.sol` enxuto — mint exclusivamente via CRE

---

## 🔭 Fase 3 — Escala e Governança (Visão)

Expansão do protocolo para uso real com governança descentralizada e integração com bases oficiais de propriedade intelectual.

- [ ] Deploy em mainnet
- [ ] Governança descentralizada — decisões em zona cinza votadas pela comunidade
- [ ] Integração com base de dados do INPI
- [ ] Suporte a múltiplas jurisdições e idiomas
- [ ] Dashboard público de marcas registradas
- [ ] API pública para consulta de similaridade
- [ ] Programa de incentivo para registros pioneiros

---

## 🧠 Visão do Protocolo

> Qualquer marca registrada no MarcasChain passou por dois filtros independentes — análise matemática on-chain e análise semântica via inteligência artificial — com resultado gravado permanentemente no IPFS e verificável por qualquer pessoa, a qualquer momento, sem depender de nenhuma entidade central.
