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

## Convert PDFs to TEI P5

This is actually the first step, but usually not necessary, as the comparatively expensive TEI P5 files in `p5` folder are not deleted by `make clean`.

### Start GOBID server

```bash
docker run --rm --init -v ./grobid.yaml:/opt/grobid/grobid-home/config/grobid.yaml --ulimit core=0 -e JAVA_OPTS=-Xmx400g -p 8070:8070 grobid/grobid:0.8.1
```

### Run client to convert PDFs to TEI P5

```bash
java -jar lib/org.grobid.client-0.5.4-SNAPSHOT.one-jar.jar -n 100 -in /mnt/data/Diss-Sample/PDF -out p5
```
