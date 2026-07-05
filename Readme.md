# Conversion tools for Deutsches Fachliteraturkorpus (DeFaKo@DNB)

## License

The software in this repository (Makefile, shell scripts, XSLT stylesheets,
and auxiliary configuration files) is licensed under the
[Apache License, Version 2.0](LICENSE).

> **Note on test data:** The TEI-P5 files under `test/resources/dnf/p5/` are
> derived from copyrighted dissertations included solely for pipeline testing.
> They may **not** be redistributed.

> **Note on sensitive data:** The `data/` directory may contain access tokens
> or other credentials.  Do **not** redistribute this directory.

## Prerequisites for building an index and running a local KorAP

- Java >=21
- Docker
- GNU Make
- curl and unzip (for fetching annotation models, jars and tools)
- xmllint and xmlstarlet (for XML validation and tests)
- A license for the SAXON XSLT processor copied to `lib/saxon-license.lic` (see [SAXONICA website](https://www.saxonica.com/))

For CI/CD environments, define `SAXON_LICENSE` as a GitLab CI **file** variable
containing the license; it is copied to `lib/saxon-license.lic` before the
build.

## Configuration of the Conversion and Indexing Pipeline

Most build settings can be overridden on the `make` command line, for example
`make index KRILL_INDEXER_HEAP=64g`.
Testing should work with the default settings, but you still need to copy a
Saxon license to `lib/saxon-license.lic` before running the tests.

| Variable | Default | Purpose |
| --- | --- | --- |
| `SRC_DIR` | `./p5` | Source directory containing TEI-P5 files (`*.tei.xml`, produced by GROBID). When running `make test`, this is set to `test/resources/dnf/p5`. |
| `YEARS` | `00` to `20` | Publication year suffixes to build. When running `make test`, this is set to the years covered by the test data. |
| `TARGET_DIR` | `target` | Directory for generated I5, KorAP XML, Krill archives, and the Lucene index. |
| `MAX_THREADS` | `nproc` | General thread-count setting used by some build commands. |
| `KORAPXMLTOOL_MODELS_PATH` | `models` | Model directory exported to KorAP XML tooling. |
| `KRILL_INDEXER_HEAP` | `500g` | Java heap passed to `Krill-Indexer.jar`. The production default is deliberately high because too little heap can damage an in-place index update. Use a smaller value for local test or subset runs. |
| `SAXON_LICENSE_FILE` | `lib/saxon-license.lic` | Saxon EE license file checked before I5 conversions. |
| `SAXON` | Java command using `lib/saxon-ee-12.9.jar` | Saxon invocation used for XSLT conversions. |
| `SLACK` | `slack` if available, otherwise `echo` | Notification command used after Krill archive creation. |

Saxon EE, `Krill-Indexer.jar` and `korapxmltool` are not committed to the
repository; they are downloaded automatically by the respective make targets.

## Testing

### Run TEI I5 conversion tests on local test data

```bash
make test
```

### Build test index

```bash
make test index KRILL_INDEXER_HEAP=8g
```

### Run local KorAP with test index

```bash
docker compose -f test-compose.yml up -d

xdg-open http://localhost:4013/?q=Test
```

### Stop local KorAP

```bash
docker compose -f test-compose.yml down
```

## Convert PDFs to TEI P5

This is actually the first step, but usually not necessary, as the comparatively expensive TEI P5 files in `p5` folder are not deleted by `make clean`.

### Start GROBID server

```bash
docker run --rm --init -v ./grobid.yaml:/opt/grobid/grobid-home/config/grobid.yaml --ulimit core=0 -e JAVA_OPTS=-Xmx400g -p 8070:8070 grobid/grobid:0.8.1
```

### Run client to convert PDFs to TEI P5

```bash
java -jar lib/org.grobid.client-0.5.4-SNAPSHOT.one-jar.jar -n 100 -in /mnt/data/Diss-Sample/PDF -out p5
```

The GROBID client jar is a locally built one-jar of
[grobid-client-java](https://github.com/kermitt2/grobid-client-java); it is
kept in the repository because no release artifact exists upstream.

## Production

### Build a new KorAP index

```bash
make -j $(( $(nproc) / 2 )) index
```

By default, all TEI-P5 files found recursively under `./p5` are used.

The index will be written to `target/dnf.index`. If that path already exists,
the Lucene index is updated in place.

### Run the published instances

Up to three instances run in parallel, each from its own compose file:

- **current** — path `/defako`, port **4010**, corpus DeFaKo@DNB — `defako-current-compose.yml`
- **alpha** — path `/defako-alpha`, port **4011**, corpus DeFaKo-α@DNB — `defako-alpha-compose.yml`
- **old** — path `/defako-old`, port **4012**, corpus DeFaKo-old@DNB — `defako-old-compose.yml`

Each instance reads its index from a symlink in the project directory. Create
it once, pointing at the built Lucene index, e.g. for current:

```bash
ln -s /path/to/target/dnf.index ./defako-current.index   # defako-alpha.index / defako-old.index analogously
```

Start / stop (example: current — for alpha/old just swap the file name):

```bash
docker compose -f defako-current-compose.yml up -d
docker compose -f defako-current-compose.yml down
```

Each compose file sets its own project name (`name: defako-current` etc.), so
the containers are already distinguishable in `docker ps` as
`defako-current-kalamar-1`, `defako-current-kustvakt-1`, … (no `-p` flag
needed). They also use `restart: unless-stopped`, so dockerd restarts them
automatically after a reboot (no systemd unit needed). Override the index path
with `INDEX=/path/to.index docker compose -f defako-current-compose.yml up -d`.

### httpd configuration

Route each path to its instance port. List the more specific paths first.
Replace `localhost` with the host name or IP where the containers are
reachable if the reverse proxy does not run on the Docker host itself:

```apache
ProxyPass        /defako-alpha http://localhost:4011/defako-alpha
ProxyPassReverse /defako-alpha http://localhost:4011/defako-alpha
ProxyPass        /defako-old   http://localhost:4012/defako-old
ProxyPassReverse /defako-old   http://localhost:4012/defako-old
ProxyPass        /defako       http://localhost:4010/defako
ProxyPassReverse /defako       http://localhost:4010/defako
```

## References

Kupietz, Marc/Leinen, Peter/Diewald, Nils (2024): Towards a Very Large German Academic Corpus: Step 1: Building and Making Available a Corpus of 10,000 Doctoral Dissertations. Talk given at the [*Workshop on Comparable and Interoperable Corpora of Academic Texts @CLARIN2024*](https://www.clarin.eu/event/2024/workshop-comparable-and-interoperable-corpora-academic-texts-clarin2024) on 2024-10-18, Barcelona. <https://corpora.ids-mannheim.de/slides/2024-10-17-Towards-a-German-Academic-Corpus/#/>.
