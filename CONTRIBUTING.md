# Contributing

**This tap is closed to contributions.**

It is a personal tap. It exists to package the software I use and ship, on my own
schedule, to my own standards. Pull requests will not be reviewed and issues are
disabled.

That is not a judgement on you — it is a scope decision. A tap that accepts formulae
becomes a distribution, and I do not want to run a distribution.

## If something here is broken

Open an issue against **the upstream project**, not this repository. A formula here is
a thin packaging wrapper; almost every bug you hit will live upstream.

If the packaging itself is genuinely wrong — wrong SHA, broken `test do`, a missing
dependency — you are welcome to email me. I would rather know.

## If you want the software

```bash
brew install scrothers/tap/<formula>
```

## If you want to package it yourself

Fork away, or start your own tap:

```bash
brew tap-new <user>/<repo> --github-packages
```

[How to Create and Maintain a Tap](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap)
is the documentation I followed. The [Formula Cookbook](https://docs.brew.sh/Formula-Cookbook)
covers writing the formula itself.
