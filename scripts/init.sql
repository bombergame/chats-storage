CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE IF NOT EXISTS chat (
  id uuid
    CONSTRAINT chat_id_pk PRIMARY KEY,

  room_id uuid
    CONSTRAINT chat_room_id_null NULL
    CONSTRAINT chat_room_id_unique UNIQUE
);

CREATE TABLE IF NOT EXISTS participant (
  chat_id uuid
    CONSTRAINT participants_chat_id_not_null NOT NULL
    CONSTRAINT participants_chat_id_fk REFERENCES chat(id),

  profile_id BIGINT
    CONSTRAINT participants_profile_id_not_null NOT NULL,

  CONSTRAINT participants_chat_id_profile_id_unique UNIQUE(chat_id, profile_id)
);

CREATE TABLE IF NOT EXISTS message (
  id uuid
    CONSTRAINT message_id_pk PRIMARY KEY,

  chat_id uuid
    CONSTRAINT message_chat_id_not_null NOT NULL
    CONSTRAINT message_chat_id_fk REFERENCES chat(id),

  profile_id BIGINT
    CONSTRAINT message_profile_id_not_null NOT NULL,

  content TEXT
    CONSTRAINT message_content_not_null NOT NULL,

  posted_timestamp TIMESTAMP WITH TIME ZONE
    DEFAULT(CURRENT_TIMESTAMP)
    CONSTRAINT message_posted_timestamp_not_null NOT NULL
);

CREATE OR REPLACE FUNCTION create_or_get_chat(_profile_id_ BIGINT)
RETURNS uuid
AS $$
  DECLARE _chat_id_ uuid;
BEGIN
  INSERT INTO chat(id) VALUES(uuid_generate_v4())
    RETURNING chat.id INTO _chat_id_;

  INSERT INTO participant(chat_id, profile_id) VALUES(_chat_id_, _profile_id_);
  RETURN _chat_id_;
END;
$$
LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION create_or_get_chat(
  _profile_id1_ BIGINT, _profile_id2_ BIGINT)
RETURNS uuid
AS $$
  DECLARE _chat_id_ uuid;
  DECLARE _num_users_ INTEGER;
BEGIN
  SELECT p.chat_id, COUNT(*)
  FROM participant p
  WHERE p.profile_id = _profile_id1_ OR
    p.profile_id = _profile_id2_
  GROUP BY p.chat_id
  INTO _chat_id_, _num_users_;

  IF _num_users_ = 2 THEN
    RETURN _chat_id_;
  END IF;

  INSERT INTO chat(id, room_id)
    VALUES(uuid_generate_v4(), NULL)
    RETURNING chat.id INTO _chat_id_;

  INSERT INTO participant(chat_id, profile_id)
    VALUES(_chat_id_, _profile_id1_);
  INSERT INTO participant(chat_id, profile_id)
    VALUES(_chat_id_, _profile_id2_);
  RETURN _chat_id_;
END;
$$
LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION get_chat_users(_chat_id_ uuid)
RETURNS BIGINT
AS $$
  SELECT p.profile_id FROM participant p
  WHERE p.chat_id = _chat_id_;
$$
LANGUAGE SQL;

CREATE OR REPLACE FUNCTION add_player_to_chat(_chat_id_ uuid, _player_id_ BIGINT)
  RETURNS VOID
AS $$
BEGIN
  IF NOT EXISTS(
    SELECT * FROM chat WHERE chat.id = _chat_id_
  ) THEN
    RAISE 'chat not found';
  END IF;
  INSERT INTO participant(chat_id, profile_id)
  VALUES(_chat_id_, _player_id_);
END;
$$
LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION add_message(
  _chat_id_ uuid, _player_id_ BIGINT, _content_ TEXT
) RETURNS VOID
AS $$
BEGIN
  IF NOT EXISTS(
    SELECT * FROM chat ch WHERE ch.id = _chat_id_
  ) THEN
    RAISE 'chat not found';
  END IF;
  IF NOT EXISTS(
    SELECT * FROM participant p
    WHERE p.chat_id = _chat_id_ AND
      p.profile_id = _player_id_
  ) THEN
    RAISE 'user not in chat';
  END IF;
  INSERT INTO message(id, chat_id, profile_id, content)
    VALUES(uuid_generate_v4(), _chat_id_, _player_id_, _content_);
END;
$$
LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION get_messages(
  _chat_id_ uuid, _page_index_ INTEGER, _page_size_ INTEGER)
RETURNS SETOF message
AS $$
  SELECT * FROM message
  WHERE message.chat_id = _chat_id_
  ORDER BY message.posted_timestamp
  LIMIT _page_size_
  OFFSET _page_index_ * _page_size_;
$$
LANGUAGE SQL;
