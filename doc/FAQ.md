# FAQ

## What do I need to run the scripts in `./scripts/`?

* [csvizmo](https://github.com/Notgnoshi/csvizmo) installed in your `$PATH`
  * gnuplot
* csvtool
  * Fedora: `sudo dnf install ocaml-csv`
  * Ubuntu: `sudo apt install csvtool`

## How do I add a new session to an existing campaign?

1. Add a `session-<index>.csv` file to `data/<campaign>/sessions/`. The file should have two
   columns:

   * `session`: The session number
   * `roll`: The d20 roll value

2. Run the `./scripts/add_session.sh` script. It will discover the newly created session file and
   update the campaign statistics accordingly.

   ```sh
   ./scripts/add_session.sh
   ```

3. Sanity check the changes to the README:

   ```sh
   git diff README.md
   ```
4. Commit and push

## How do I add a new campaign?

1. Create `data/<campaign>/sessions/`
2. Create `figures/<campaign>/sessions/`
3. Add your campaign's first session with the process above
