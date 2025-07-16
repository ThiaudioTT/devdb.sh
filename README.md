# Devdb.sh

Devdb.sh is a simple script in shell to manage development databases. It allows you to easily start, reset, and connect to a local development PostgreSQL database or Redis instance using Docker.

```bash
sudo wget -qO /usr/local/bin/devdb https://github.com/ThiaudioTT/devdb.sh/raw/main/devdb.sh && sudo chmod +x /usr/local/bin/devdb
```

Now you can simply run:

```bash
devdb         # to start or resume the dev database
devdb --reset # to reset and recreate
devdb --redis # to start Redis with RedisInsight (port 5540)
```

## PostgreSQL

The script will output:

```bash
export DATABASE_URL='postgresql://postgres@127.0.0.1:5432/postgres'
```

Add that line to your shell or `.env` file to connect.

## Redis

When using the `--redis` flag, the script will output:

```bash
export REDIS_URL='redis://127.0.0.1:6379'
```

Redis features:

- Redis server on port 6379 (no password)
- RedisInsight web interface on port 5540
- Data is automatically wiped and recreated each time you run `devdb --redis`

Access RedisInsight at: <http://127.0.0.1:5540>

---

<img src="https://safebooru.org//samples/1044/sample_b291050f87ce6c95ff5644f3005fd5be5640b682.jpg?5920096"/>