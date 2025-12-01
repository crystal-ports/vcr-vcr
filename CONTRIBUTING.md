## Contributing

[Install Crystal](https://crystal-lang.org/install/) and use `shards` to install all the development dependencies:

```console
shards install
```

You should be able to run the tests now:

```console
crystal spec
```

VCR.cr uses [Spectator](https://gitlab.com/arctic-fox/spectator) for unit tests. The specs are written in a very "focused" style, where each spec is concerned only with exercising the object under test, using mocks as necessary. You can run the specs using `crystal spec`.

## Linting

Run the linter to check code style:

```console
./bin/ameba
```