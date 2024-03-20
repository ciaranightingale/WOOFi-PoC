## WOOFi $8.5 million Hack - Proof of Concept

This repository serves as a PoC demonstrating the steps taken to perform the hack which lost WOOFi ~$8.5M.

This PoC is supplementary to the following article that gives a breakdown of the hack, the vulnerabilities that allowed the hack to occur and how to avoid similar hacks: [WOOFi Hack Analysis](https://www.cyfrin.io/blog/hack-analysis-into-woofi-exploit)

## Documentation

https://book.getfoundry.sh/

## Usage

To use this proof of concept, first clone the repository.

```shell
$ git clone https://github.com/ciaranightingale/WOOFi-PoC
```

Then, install the dependencies:

```shell
$ forge install
```

### Build

```shell
$ forge build
```

### Test (with state variable output)

```shell
$ forge test -vvv
```
