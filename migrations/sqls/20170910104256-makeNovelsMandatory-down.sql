CREATE TABLE narration_exports (id integer AUTO_INCREMENT PRIMARY KEY,
                                character_id integer,
                                token varchar(128),
                                created timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                FOREIGN KEY (character_id) REFERENCES characters(id)) DEFAULT CHARSET=utf8;

INSERT INTO narration_exports (character_id, token)
SELECT id, novel_token FROM characters
WHERE novel_token IS NOT NULL;

ALTER TABLE characters DROP novel_token;
