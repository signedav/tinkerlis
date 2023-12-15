ALTER TABLE uuid_test4.gebaeude DROP COLUMN besitzerin;
ALTER TABLE uuid_test4.gebaeude ADD COLUMN besitzerin VARCHAR;

ALTER TABLE uuid_test4.gebaeude DROP COLUMN t_id;
ALTER TABLE uuid_test4.gebaeude ADD COLUMN t_id VARCHAR;

ALTER TABLE uuid_test4.gebaeude  ALTER COLUMN t_id SET DEFAULT uuid_generate_v4();

ALTER TABLE uuid_test4.besitzerin DROP COLUMN t_id;
ALTER TABLE uuid_test4.besitzerin ADD COLUMN t_id VARCHAR;
ALTER TABLE uuid_test4.besitzerin  ALTER COLUMN t_id SET DEFAULT uuid_generate_v4();