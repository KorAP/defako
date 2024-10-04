# Conversion tools for Deutsches Fachliteraturkorpus (DeFaKo@DNB)

## Testing

### Run TEI I5 conversion tests on local test data

```bash
make -j $(nproc) test
```

### Build test index

```bash
make -j $(nproc) test index
```

### Run local KorAP with test index

```bash
INDEX=./target/dnf.index docker compose -p korap4dnb --profile=lite -f korap4dnb-compose.yml up -d

xdg-open http://localhost:4000/?q=Test
```

### Stop local KorAP

```bash
docker compose -p korap4dnb down
```
