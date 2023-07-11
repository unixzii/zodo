# zodo

A minimalist CLI todo list.

## Usage

```
Usage: zodo [command] [options]

Commands:
  add [contents]        Add a todo item
  rm [item_id]          Remove a todo item
  ls                    List all the todo items
```

## Install

### Via GitHub Releases

Go to [release page](https://github.com/unixzii/zodo/releases), click on `Assets` at the bottom to show the binary files available for downloading.

### Build Locally

Prerequisite:

- Zig 0.10.0 or newer

Clone this repository and run the commands below:

```shell
cd zodo
zig build
```

The build artifact is at `./zig-out/bin` directory. To build in release mode, run `zig build -Drelease-small=true`.

## FAQ

### Where is the database file?

The database file is `.zodo_db` at your home directory. This is the only file created by `zodo`, you can safely delete it when the program no longer used.

### Why is the database file getting larger and larger?

The database is stored as an append-only journal file. For performance considerations, existing record lines will not be touched once appended. As a benefit, all your history data are preserved in the journal file, and you can view it with any text editor.

In the future, we can provide a command to prune your database by reconstructing the whole journal file.

## License

MIT
