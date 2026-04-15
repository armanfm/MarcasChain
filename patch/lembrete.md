## Patch — Limite de caracteres no registro

- Definir tamanho mínimo da marca: **3 caracteres**
- Definir tamanho máximo da marca: **20 caracteres**

### Regra
- Rejeitar strings com menos de 3 caracteres
- Rejeitar strings com mais de 20 caracteres

### Justificativa
- Evita spam (nomes muito curtos)
- Evita abuso/gas alto (strings muito longas)
- Mantém padrão consistente de registro

### Observação
- Os limites podem necessitar de calibração com base no uso real do sistema
