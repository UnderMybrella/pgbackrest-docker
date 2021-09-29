# pgbackrest

A simple wrapper image around psql (currently: postgresql:12-buster) that includes a setup for pgBackRest.

All environmental variables can also be read from files (by appending _FILE to the end of the name).

BACKREST_STANZA - Required, the name of the stanza for this dataset.
BACKREST_REPO - Required (defaults to /var/lib/pgbackrest/data), the repository to back up to.
BACKREST_CIPHER_PASS - Required, the password to use for encryption.
BACKREST_CIPHER_TYPE - Defaults to 'aes-256-cbc'. The encryption type to use.
BACKREST_COMPRESS_TYPE - Defaults to 'zst'. The compression type to use.
BACKREST_COMPRESS_LEVEL - Defaults to '6'. The level of compression to use.
BACKREST_RETENTION_FULL - Defaults to '1'. The number of full backups to retain.
BACKREST_RETENTION_DIFF - Defaults to '7'. The number of differential backups to retain.