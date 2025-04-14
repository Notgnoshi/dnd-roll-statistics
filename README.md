# D&D Roll Statistics

All d20 rolls manually recorded during the session, and processed afterwards.

# TODO

* [x] Script to automate statistics and plotting for each CSV
* [ ] Generate the README with a template and a script from any sessions in `data/`

# How to use

Add a new CSV to the `data/` directory, in a column named `roll`. Then run the `./generate.sh`
script on the new CSV. It require the `csvplot` and `csvstats` tools from
https://github.com/Notgnoshi/csvizmo to be installed somewhere in your `$PATH`

```sh
./generate.sh ./data/*.csv
```
