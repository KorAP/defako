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
INDEX=./target/dnf.index docker compose -p defako --profile=lite -f korap4dnb-compose.yml up -d

xdg-open http://localhost:4001/?q=Test
```

### With ssh tunnel from localhost to the DeFaKo@DNB server

```bash
ssh -L 4001:localhost:4001 korap.dnb.de
xdg-open http://localhost:4001/?q=Test
```


### Stop local KorAP

```bash
docker compose -p defako down
```
