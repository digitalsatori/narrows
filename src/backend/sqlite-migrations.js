import Q from "q";

function migrationApplied(db, migrationName) {
    return Q.ninvoke(
        db,
        "get",
        "SELECT COUNT(*) AS cnt FROM _migrations WHERE name = ?",
        migrationName
    ).then(function(row) {
        return row.cnt > 0;
    }).catch(function() {
        return false;
    });
}

function markMigrationApplied(db, migrationName) {
    return Q.ninvoke(
        db,
        "run",
        "INSERT INTO _migrations (name) VALUES (?)",
        migrationName
    );
}

function upgradeDb(db, migrations) {
    const migrationPromise = Q(true);

    migrations.forEach(migration => {
        migrationPromise.then(() => {
            return migrationApplied(db, migration.name).then(result => {
                if (!result) {
                    return migration(db).then(() =>
                        markMigrationApplied(db, migration.name)
                    );
                }

                return true;
            }).catch(err => {
                console.error("There was some horrible error???", err);
            });
        });
    });

    return migrationPromise;
}

export default upgradeDb;