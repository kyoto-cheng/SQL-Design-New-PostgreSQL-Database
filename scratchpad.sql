-- Allow new users to register by creating a user table: 
-- Each username has to be unique
-- Usernames can be composed of at most 25 characters
-- Usernames can’t be empty
-- We won’t worry about user passwords for this project

CREATE Table "users"
(
id SERIAL PRIMARY KEY,
last_login TIMESTAMP,
user_name VARCHAR(25) UNIQUE NOT NULL,
CONSTRAINT "user_names_not_empty" CHECK(LENGTH(TRIM("user_name"))>0));

-- Allow registered users to create new topics by creating a topic table:
-- Topic names have to be unique.
-- The topic’s name is at most 30 characters
-- The topic’s name can’t be empty
-- Topics can have an optional description of at most 500 characters.

CREATE Table "topics"
(
id SERIAL PRIMARY KEY, 
topic_name VARCHAR(30) UNIQUE NOT NULL,
description VARCHAR(500),
CONSTRAINT "topic_names_not_empty" CHECK(LENGTH(TRIM("topic_name"))>0));

CREATE INDEX ON "topics" ("topic_name" VARCHAR_PATTERN_OPS);

-- Allow registered users to create new posts on existing topics by creating a post table:
-- Posts have a required title of at most 100 characters
-- The title of a post can’t be empty.
-- Posts should contain either a URL or a text content, but not both.
-- If a topic gets deleted, all the posts associated with it should be automatically deleted too.
-- If the user who created the post gets deleted, then the post will remain, but it will become dissociated from that user.

CREATE Table "posts"
(
id SERIAL PRIMARY KEY,
created_on TIMESTAMP,
post_title VARCHAR(100) NOT NULL,
post_url TEXT,
post_text_content TEXT,
topic_id INTEGER,
user_id INTEGER,   
FOREIGN KEY(topic_id) REFERENCES "topics" ON DELETE CASCADE,
FOREIGN KEY(user_id) REFERENCES "users" ON DELETE SET NULL,
CONSTRAINT "post_title_not_empty" CHECK (LENGTH(TRIM("post_title"))>0),
CONSTRAINT "url_or_text_content" CHECK (
    (LENGTH(TRIM("post_url"))>0 AND LENGTH(TRIM("post_text_content"))=0) OR (LENGTH(TRIM("post_url"))=0 AND LENGTH(TRIM("post_text_content"))>0)));

CREATE INDEX ON "posts" ("post_title" VARCHAR_PATTERN_OPS);
    
-- Allow registered users to comment on existing posts by creating a comment table:
-- A comment’s text content can’t be empty.
-- Contrary to the current linear comments, the new structure should allow comment threads at arbitrary levels.
-- If a post gets deleted, all comments associated with it should be automatically deleted too.
-- If the user who created the comment gets deleted, then the comment will remain, but it will become dissociated from that user.
-- If a comment gets deleted, then all its descendants in the thread structure should be automatically deleted too.

CREATE Table "comments"
(
id SERIAL PRIMARY KEY,
created_on TIMESTAMP,
comment_text_content TEXT NOT NULL,
post_id INTEGER,
user_id INTEGER,
FOREIGN KEY(post_id) REFERENCES "posts" ON DELETE CASCADE,
FOREIGN KEY(user_id) REFERENCES "users" ON DELETE SET NULL,
CONSTRAINT "comment_text_content_not_empty" CHECK(LENGTH(TRIM("comment_text_content"))>0)
);

-- Make sure that a given user can only vote once on a given post by creating a vote table:
-- Hint: you can store the (up/down) value of the vote as the values 1 and -1 respectively.
-- If the user who cast a vote gets deleted, then all their votes will remain, but will become dissociated from the user.
-- If a post gets deleted, then all the votes for that post should be automatically deleted too.

CREATE Table "votes"
(
vote_status INTEGER NOT NULL,   
post_id INTEGER,
user_id INTEGER,
FOREIGN KEY(post_id) REFERENCES "posts" ON DELETE CASCADE,
FOREIGN KEY(user_id) REFERENCES "users" ON DELETE SET NULL,
CONSTRAINT "vote_up_or_down" CHECK("vote_status" = 1 or "vote_status" = -1),
CONSTRAINT "one_vote_per_user" UNIQUE(user_id, post_id)
);


INSERT INTO "users"("user_name")
SELECT DISTINCT username
FROM bad_posts
UNION
SELECT DISTINCT username
FROM bad_comments
UNION
SELECT DISTINCT regexp_split_to_table(upvotes,',')
FROM bad_posts
UNION
SELECT DISTINCT regexp_split_to_table(downvotes,',')
FROM bad_posts;
 
INSERT INTO "topics"("topic_name")
SELECT DISTINCT topic 
FROM bad_posts;

INSERT INTO "posts"("user_id", "topic_id", "post_title", "post_url", "post_text_content")
SELECT DISTINCT u.id, t.id, LEFT(b.title,100), b.url, b.text_content
FROM bad_posts b
JOIN users u 
ON b.username = u.user_name
JOIN topics t
ON b.topic = t.topic_name;
 
INSERT INTO "comments"("user_id", "post_id", "comment_text_content")
SELECT u.id, p.id, b.text_content
FROM bad_comments b
JOIN users u 
ON b.username = u.user_name 
JOIN posts p
ON p.id = b.post_id; 

INSERT INTO "votes"("user_id", "post_id", "vote_status")
SELECT u.id, t.id, 1 as vote_up 
FROM users u
JOIN (SELECT id, REGEXP_SPLIT_TO_TABLE(upvotes, ',') upvote_users
     FROM bad_posts) t 
ON u.user_name = t.upvote_users;

INSERT INTO "votes"("user_id", "post_id", "vote_status")
SELECT u.id, t.id, -1 as vote_down
FROM users u
JOIN (SELECT id, REGEXP_SPLIT_TO_TABLE(downvotes, ',') downvote_users
     FROM bad_posts) t 
ON u.user_name = t.downvote_users;