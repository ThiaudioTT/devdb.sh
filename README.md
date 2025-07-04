# Devdb.sh

Devdb.sh is a simple script in shell to manage a development PostgreSQL database. It allows you to easily start, reset, and connect to a local development database using Docker.

```bash
sudo wget -qO /usr/local/bin/devdb https://github.com/ThiaudioTT/devdb.sh/raw/main/devdb.sh && sudo chmod +x /usr/local/bin/devdb
```

Now you can simply run:

```bash
devdb         # to start or resume the dev database
devdb --reset # to reset and recreate
```

The script will output:

```bash
export DATABASE_URL='postgresql://postgres@127.0.0.1:5432/devdb'
```

Add that line to your shell or `.env` file to connect.