# 🧠 Protocolo de Registro de Marcas On-Chain

Sistema descentralizado para registro de marcas baseado em análise de similaridade e validação automática.

---

## ⚙️ Funcionamento

O protocolo permite registrar nomes (marcas) na blockchain com base em um sistema de análise que compara similaridade com marcas existentes.

O processo é dividido em três etapas:

---

### 🔍 1. Validação de Formato

O nome enviado deve seguir obrigatoriamente:

- letras minúsculas (`a-z`)
- números (`0-9`)
- espaços simples
- sem acentos ou símbolos

Entradas fora desse padrão são rejeitadas diretamente pelo contrato.

---

### 📊 2. Análise de Similaridade

O nome é comparado com:

- todas as marcas já registradas
- todas as marcas em solicitação (pendentes)

O sistema calcula um **score de similaridade (0–100)** com base em:

- comparação de caracteres
- inversão de string
- divisão e combinação de palavras
- reorganização de termos

---

### ⚖️ 3. Decisão

Com base no score:

| Score | Resultado |
|------|----------|
| > 72 | ❌ Rejeitado automaticamente |
| 70 – 72 | ⚖️ Enviado para governança |
| < 70 | ✅ Aprovado automaticamente |

---

## 🧾 Registro de Marca

### ✅ Registro direto

Se aprovado:

- o usuário paga em ETH
- a marca é registrada imediatamente

---

### ⚖️ Governança

Se estiver na faixa intermediária:

- o usuário envia um stake em ETH
- a solicitação entra na lista de governança
- o owner decide:
  - aprovar → marca registrada
  - rejeitar → stake devolvido

---

### ❌ Rejeição

Se o score for alto:

- a transação é bloqueada
- a marca não pode ser registrada

---

## ⏳ Sistema de Tempo

Cada marca registrada pode ter tempo ativo associado.

Funcionalidades:

- pagamento por ano em ETH
- extensão do tempo (renovação)
- verificação de validade
- expiração automática (baseada em timestamp)

---

## 🔐 Regras do Sistema

- o contrato exige formato válido (não depende do frontend)
- não há normalização de texto (input já deve estar correto)
- o hash da marca é gerado com `keccak256(bytes(nome))`
- apenas o dono pode pagar ou renovar tempo
- registros são únicos por nome

---

## 🔄 Interação entre Contratos

O sistema é dividido em dois contratos:

### `Marcas`
- registro
- análise
- governança

### `MarcasTempo`
- controle de tempo
- pagamentos anuais
- renovação

Ambos utilizam o mesmo padrão de hash para garantir consistência.

---

## 🧠 Características

- análise on-chain
- decisão automática por score
- fallback humano (governança)
- proteção contra registros similares
- consistência entre contratos

- ---

1-0x9b34d88696Ed58C665f7975f2aD66396118F068f
2-0x3D841E95360faBA3692845730acDd4DD491eaC21
