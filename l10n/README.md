# Traduções do plugin

- O texto-fonte do código é inglês.
- Edite os arquivos `koreader.po`.
- O KOReader no Kindle carrega `koreader.mo`.
- Não edite o `.mo` manualmente.

Idiomas mantidos:

```text
pt/koreader.po      Português
pt_BR/koreader.po   Português do Brasil
zh_CN/koreader.po   Chinês simplificado
en/koreader.po      Catálogo-fonte auxiliar
```

Depois de alterar qualquer `.po`, execute na raiz do plugin:

```bash
python3 tools/l10n_audit.py --compile
```

Somente copie o plugin para o Kindle depois que a auditoria terminar com:

```text
Catálogos completos e arquivos MO válidos.
```
