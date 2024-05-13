-- A User account

DROP SCHEMA IF EXISTS dv CASCADE;
CREATE SCHEMA dv;

CREATE TABLE dv.account (
       id integer NOT NULL, -- Not a PRIMARY KEY because of foreign tables
       username varchar,
       email varchar UNIQUE, -- one account per email address
       salt integer, --protects against dictionary attacks
       hashpassword varchar,
       neighborhood varchar,
       nearbyListView boolean, -- true if user prefers list view, false if map view
       needASeat boolean, -- true if user specified that they need a seat for health reasons
       isBlind boolean, -- whether the user specified if they are blind/low vision
       isCane boolean, -- whether the user specified if they are a cane/walker user
       isCognitive boolean, -- whether the user specified if they have cognitive disability
       isDeaf boolean, -- whether the user specified if theyare deaf/hard of hearing
       isWheelchair boolean, -- whether the user specified if they are a wheelchair/scooter user
       isOtherDisability boolean, -- whether the user specified if they have other disability
       creation timestamp without time zone default now(), -- the time when the account is created
       device_id varchar, -- the device_id when the account is created
       session_id integer, -- session_id of the client when the account is created
       firstname varchar,
       lastname varchar,
       verified timestamp without time zone
);

-- Since using PRIMARY KEYS will not work with foreign tables
-- this code instead creates a trigger that will run whenever a new row is inserted.
-- This trigger calls a function which sets the id value to the next value in
-- the sequence.
CREATE SEQUENCE dv.account_id_seq;

CREATE OR REPLACE FUNCTION dv.generate_id() RETURNS TRIGGER AS $new_account$
       BEGIN 
       	     IF NEW.id IS NULL THEN 
	     	NEW.id := nextval('dv.account_id_seq'::regclass); 
	     END IF; 
       	     RETURN NEW;
       END;
    $new_account$ LANGUAGE plpgsql;

CREATE TRIGGER new_account
       BEFORE INSERT ON dv.account
       FOR EACH ROW
       EXECUTE PROCEDURE dv.generate_id();


DROP SCHEMA IF EXISTS r CASCADE;
CREATE SCHEMA r;

-- this table schema copy of h.trace schema
CREATE TABLE r.trace (
    id SERIAL PRIMARY KEY,
        session_id INTEGER,
        session_record_counter INTEGER,
    agency_id INTEGER,
    trace_time_hour INTEGER,
    trace_time_minute INTEGER,
    trace_time_second INTEGER,
    trace_lat FLOAT8,
    trace_lon FLOAT8,
    trip_id VARCHAR,
    device_id VARCHAR,
    fullness FLOAT4,
    stop_time_id INTEGER,   -- the id of stop_time
    stop_id VARCHAR,    -- the stop_id of this point in stop_time
    stop_sequence INTEGER   -- the stop_sequence of this trip in stop_time
);

-- the error on the current historical estimate
CREATE TABLE r.error (
    agency_id INTEGER,
    stop_time_id INTEGER,
    intercept_time REAL,
    error REAL, -- error in arrival time in seconds, subtract to correct
    cnt INTEGER -- number of traces contributing to this estimate
);

CREATE TABLE r.avl_error (
       agency_id INTEGER,
       stop_time_id INTEGER,
       trip_id VARCHAR,
       stop_sequence INTEGER,
       error REAL
);

-- update fullness
CREATE TABLE r.fullness (
    agency_id INTEGER,
    stop_time_id INTEGER,
    error REAL, -- error on the estimate from historical fullness
    cnt INTEGER,
    PRIMARY KEY (agency_id, stop_time_id)
);


DROP SCHEMA IF EXISTS m CASCADE;
CREATE SCHEMA m;

CREATE TABLE m.trip_counter (
       trip_count INTEGER,
       agency_id_id VARCHAR
);

INSERT INTO m.trip_counter (trip_count, agency_id_id) VALUES (0, 'PAAC');
INSERT INTO m.trip_counter (trip_count, agency_id_id) VALUES (0, 'NYC');



CREATE TYPE m.client_screen AS ENUM('tiramisu_notes', 'agency_notes', 'stop_notes', 'route_notes', 'nearby_map', 'nearby_list', 'usage', 'my_info', 'favorites', 'settings');

CREATE TABLE m.messages (
        id INTEGER NOT NULL,
    message_title VARCHAR,
    message VARCHAR,         -- message that is to send to the user
    destination_screen m.client_screen,
    num_conditions INTEGER,
    agency_id INTEGER,      -- reference m.agency table. the agency the message is from
    device_id VARCHAR,
    group_id VARCHAR, 
    app_version VARCHAR,    -- application version number
    device VARCHAR,         -- for a specific device model
    stamp TIMESTAMP, -- left in for backwards compatibility
    start_date TIMESTAMP,
    end_date TIMESTAMP,
    trigger_cond VARCHAR
);

CREATE TABLE m.popup_log (
       message_id INTEGER,
       device_id VARCHAR,
       event VARCHAR,
       stamp TIMESTAMP
);

-- m.popup_log is only updated every few hours, so this table is used
-- to keep track of when users see a message so that users only see
-- one message per day. m.popup_log should be used for more detailed information.
CREATE TABLE m.popup_user_log (
       device_id VARCHAR,
       stamp TIMESTAMP DEFAULT NOW()
);

-- Since using PRIMARY KEYS will not work with foreign tables
-- this code instead creates a trigger that will run whenever a new row is inserted.
-- This trigger calls a function which sets the id value to the next value in
-- the sequence.
CREATE SEQUENCE m.popup_id_seq;

CREATE OR REPLACE FUNCTION m.generate_id() RETURNS TRIGGER AS $new_popup$
       BEGIN 
             IF NEW.id IS NULL THEN 
            NEW.id := nextval('m.popup_id_seq'::regclass); 
         END IF; 
             RETURN NEW;
       END;
    $new_popup$ LANGUAGE plpgsql;

CREATE TRIGGER new_popup
       BEFORE INSERT ON m.messages
       FOR EACH ROW
       EXECUTE PROCEDURE m.generate_id();

-- This includes tables used in debugging and simulation


-- Note that ordering is significant for PostgreSQL ENUMS.  
-- The source_type ENUM must be defined with the source types in 
-- increasing order from (presumably) least accurate to most accurate.  
CREATE TYPE m.source_type AS ENUM('schedule', 'historical', 'real-time-user','avl');

CREATE SEQUENCE m.trace_id_seq;

-- This table is used to store error statistic when inserting avl 
CREATE TABLE m.error_statistic (
    id integer NOT NULL,
    agency_id INTEGER,
    trip_id TEXT,
    route_id CHARACTER VARYING,
    route_short_name CHARACTER VARYING,
    vehicle_id INTEGER,
    avl_lat DOUBLE PRECISION,
    avl_lon DOUBLE PRECISION,
    avl_time INTEGER,
    avl_date DATE,
    estimated_time DOUBLE PRECISION,
    error DOUBLE PRECISION,
    
    shape_id CHARACTER VARYING,
    shape_lat DOUBLE PRECISION,
    shape_lon DOUBLE PRECISION,

    prev_stop_id CHARACTER VARYING,
    prev_stop_lat DOUBLE PRECISION, 
    prev_stop_lon DOUBLE PRECISION, 
    prev_stop_dis DOUBLE PRECISION,
    prev_stop_time INTEGER,
    prev_stop_time_estimate_source m.source_type,

    next_stop_id CHARACTER VARYING,
    next_stop_lat DOUBLE PRECISION, 
    next_stop_lon DOUBLE PRECISION, 
    next_stop_dis DOUBLE PRECISION,
    next_stop_time INTEGER,
    next_stop_time_estimate_source m.source_type,
    
    stamp TIMESTAMP WITH TIME ZONE DEFAULT now()
);
ALTER TABLE ONLY m.error_statistic ALTER COLUMN id SET DEFAULT nextval('m.trace_id_seq'::regclass);
create index m_error_statistic_stamp on m.error_statistic (agency_id,stamp);



 -- t_about represents what an observation expresses about its entities. It is being replaced by the
 -- dv.about relation
   
 -- task is a specific action generated to fix a problem reported in another observation.

 -- t_entity represents the different types of persons or objects that observations can
 -- be made about.  XXX what is account for?
 
 -- t_role designates what roles, and thus what privileges, a user has in the
 -- system.
 
--CREATE TYPE dv.t_about AS ENUM ('complaint','wish','kudos','talk','task'); -- THIS IS NOW dv.about RELATION


CREATE TYPE dv.t_entity AS ENUM ('route','bus','stop','driver','rider','agency','account');
CREATE TYPE dv.t_role AS ENUM ('rider','maintenance','driver','assigner','agency');

-- TODO add status to observation? 
--
--  The basic, non entity specific information that a user submits
--
CREATE TABLE dv.observation (
       id serial PRIMARY KEY,
       agency_id INTEGER, -- references m.agency table
       title varchar, -- a shorter description of the observation's purpose
       description text, -- user's main description of the observation
       timestamp timestamp DEFAULT NOW(),
       incidentdate date, -- date the observation refers to
       incidenttime time, -- time the observation refers to
--       incidenttimestamp timestamp, -- date and time the observation refers to
       account_id integer, -- of the user who made the observation
       about_id integer, -- key into about table --- XXX add comma here!
       anonymous boolean, -- should the identity of the user submitting the report be revealed?
----------------Added to work with Forms for the time being----------
--------------- These might move into multi combo forms? -----------
       drivernumber varchar, 
       driverdescription varchar,
       riderdescription varchar,
       otherdescription varchar,
       email varchar,
-----------------------------------------------------------------------
       is_schedule integer,
       is_route integer,
       is_vehicle integer,
       is_driver integer,
       is_bus_stop integer,
       latitude FLOAT8,
       longitude FLOAT8,
       device_id varchar,
       session_id integer,
       hidden boolean default false
);

-- comments on individual observations by transit patrons
CREATE TABLE dv.observation_comment ( 
        id serial PRIMARY KEY, -- auto 
        observation_id integer, -- linked to dv.observation.id 
        stamp timestamp, -- time stamp of the comment
        comment text -- comments source varchar
);

 -- The various types of observations one can create, or what an observation expresses about 
 -- its related entities. 
 -- TODO: find a better name?
CREATE TABLE dv.about (
       id serial PRIMARY KEY,
       about varchar -- will contain one of: complaint, wish, kudos, talk
);

--TODO: Migrate these somewhere else s.t. they will still work
INSERT INTO dv.about (about) VALUES ('Complaint');
INSERT INTO dv.about (about) VALUES ('Compliment');
INSERT INTO dv.about (about) VALUES ('Suggestion');
INSERT INTO dv.about (about) VALUES ('General Discussion');

-- for upload multicombo
CREATE TABLE dv.observation_attachment (
       id serial PRIMARY KEY,
       observation_id  integer,
       attachment_id integer
);

-- A file attachment on an observation or comment
CREATE TABLE dv.attachment (
       id serial PRIMARY KEY,
       creation timestamp without time zone DEFAULT NOW(),
       attachment bytea,
       caption varchar, -- short descriptive text
--       filename varchar,
       name varchar,
       type varchar,
       mimetype varchar,
       lo_content OID,
       observation_id integer, --refers to observation the file is attached to
       comment_id integer --refers to comment that the file is attached to
);


-- A comment made on an observation
CREATE TABLE dv.comment (
       id serial PRIMARY KEY,
       creation timestamp,
       comment text,
       creatorname varchar,--username of commenter 
       account_id integer, -- referring to commenter's account
       observation_id integer -- id of observation that the comment was made on
);

 
-- For associating an observation with a specific entity.
-- Includes fields that describe an entity with information that while useful to record,
-- does not identify the specific entity.
CREATE TABLE dv.observation_entity (
       id serial PRIMARY KEY,
       observation_id integer,
       entity_id integer,
       
--       description text,
-- Route --
       routename varchar, --to support text entry of the route name
--       direction_id integer,  --in,out, or both, for task assigner's benefit.  Now a part of the Google transit data.
--Bus--
       vehiclenumber integer, --the actual number, not an entity id
--Driver--
    drivername varchar, -- for naming a driver
    drivernumber integer, --the actual number, not an entity id
--Rider--
    ridername varchar --for mentioning a specific rider
);

 -- Some item of interest about which observations can be made.
 -- Includes all items in t_entity.
 --
 -- Google doesn't represent Bus, Driver or Rider
CREATE TABLE dv.entity (
       id serial PRIMARY KEY,
       agency_id integer, -- references the primary key of an entry in g.agency
       label varchar, -- a name or string used to refer to the entity
       account_id integer,   -- for entities with a user account in the system
       entitytype dv.t_entity,   -- the type of entity
--       direction t_direction, -- the direction or a route entity --now part of Google Transit Data
       bus_id integer, -- refers to a row of dv.bus
       route_id integer, -- refers to primary key of g.route entry
       stop_id integer, -- refers to primary key of g.stop entry
       driver_id integer, --refers to a row of dv.driver
       rider_id integer -- refers to a row of dv.rider
);


-- Tables for linking observations to different entities individually.
-- Created for possible use with multi combos.
CREATE TABLE dv.observation_vehicle ( 
       id serial PRIMARY KEY, 
       observation_id integer, 
       vehicle_id integer );

CREATE TABLE dv.observation_stop ( 
       id serial PRIMARY KEY, 
       observation_id integer, 
       stop_id integer );

CREATE TABLE dv.observation_route ( 
       id serial PRIMARY KEY, 
       observation_id integer, 
       route_id integer );

CREATE TABLE dv.observation_rider ( 
       id serial PRIMARY KEY, 
       observation_id integer, 
       rider_id integer );

CREATE TABLE dv.observation_driver ( 
       id serial PRIMARY KEY, 
       observation_id integer, 
       driver_id integer );


 -- A Table to represent vehicle entities 
CREATE TABLE dv.vehicle (
       id serial PRIMARY KEY,
       agency_id integer, -- references the primary key of an entry in g.agency
       vehiclenumber varchar -- a unique identifier for a bus
);

--
 -- A Table to represent driver entities
 --
CREATE TABLE dv.driver (
       id serial PRIMARY KEY,
       drivernumber varchar, -- a unique identifier for a driver
       fullname varchar -- the driver's name
);

--
 -- A Table to represent rider entities
 --
CREATE TABLE dv.rider (
       id serial PRIMARY KEY,
       fullname varchar -- rider's full name
);

--
 --
 -- A collection of observations.  Used for grouping related observations.
 -- XXX Will we want to group different types of observations together?
 -- 
 --
CREATE TABLE dv.folder (
       id serial PRIMARY KEY,
       title varchar, -- short description of the folder
       description text, --description of what the observations collected relate to
       about_id integer --type of observations collected by folder 
);

-- A mapping of which observations are contained in which folders.
CREATE TABLE dv.folder_observation (
       id serial PRIMARY KEY,
       folder_id integer,
       observation_id integer
);

--
 -- some accounts may have more than one role, so this table keeps track of what
 -- roles a user has: rider, driver, assigner, maintenance etc.
 --
CREATE TABLE dv.account_role  (  
       id serial PRIMARY KEY,
       account_id integer,
       accountrole dv.t_role -- a role the user has in relation to 
                  -- the transit system 
);

CREATE TABLE dv.account_verification (
    id serial PRIMARY KEY,
    user_id integer,
    code character varying,
    "timestamp" timestamp without time zone DEFAULT now()
);


CREATE TYPE dv.notescategory AS ENUM ('stop', 'route', 'agency', 'tiramisu', 'trip');

CREATE TABLE dv.notes_message (
    id serial PRIMARY KEY,
    agency_id integer,
    category dv.notescategory,
    message text,
    timestamp timestamp without time zone default now(),
    user_id integer, -- joined to dv.account.id 
    stop_id varchar default null,
    route_id varchar default null,
    trip_id varchar default null,
    latitude float8,
    longitude float8,
    device_id varchar,
    session_id integer,
    like_count integer default 0, 
    comment_count integer default 0,
    reply_to integer default 0, -- id of the message that this message is replying to
    hidden boolean default false,
    dislike_count integer default 0,
    stat_timestamp timestamp DEFAULT NULL,
    deleted INTEGER,
    notice_id TEXT,  -- The notice id used by the agency
    agency_id_id TEXT, -- references m.agency(agency_id_id), -- the agency of the message
    message_url TEXT,
    start_date TIMESTAMP,
    end_date TIMESTAMP -- may be null
);

CREATE INDEX dv_notes_message_agency_id_idx ON dv.notes_message USING btree (agency_id);
CREATE INDEX dv_notes_message_trip_id_idx ON dv.notes_message USING btree (trip_id);
--CREATE INDEX dv_notes_message_agency_id_idx ON dv.notes_message(agency_id,trip_id);

CREATE TABLE dv.notes_attachment (
    id SERIAL PRIMARY KEY,
    creation TIMESTAMP DEFAULT NOW(),
    attachment bytea,
    mimetype VARCHAR,
    message_id INTEGER
);

CREATE TABLE dv.notes_like (
    id serial PRIMARY KEY,
    user_id integer, -- id of the user who like a note
    message_id integer, -- id of the message the get liked
    device_id varchar,
    session_id integer,
    timestamp timestamp default now(),
    stat_timestamp timestamp DEFAULT NULL,
    like_opt integer default 1,  -- 0 - invalid, 1 - like, 2 - dislike
    UNIQUE(user_id, message_id) -- each user can only like each message once
);

CREATE TABLE dv.test_account (
       id serial PRIMARY KEY,
       user_id integer NOT NULL,
       device_id varchar NOT NULL,
       stamp timestamp with time zone DEFAULT now()
);

CREATE TABLE dv.password_reset (
  id serial PRIMARY KEY,
  user_id INTEGER,
  code character varying,
  timestamp timestamp default now()
);

 -------------------------------------------------------------------------------
 -- Google Transit Logical Model.
 -- See http://code.google.com/transit/spec/transit_feed_specification.html
 -- for details on fields
 --
 -- Tables and Fields annotated as opt. are optional in the google transit feed 
 -- specification.
 --
 -- All tables contain a reference to an agency id in order to allow multiple 
 -- transit agencies' records to coexist in the same tables
 -- >> UserID: ftpRDPartner
 -- >> PassWD: 3QU1N0X
 ------------------------------------------------------------------------------
DROP SCHEMA IF EXISTS g CASCADE;
CREATE SCHEMA g;


CREATE TABLE g.agency (
       id serial PRIMARY KEY,
       agency_id_id varchar, -- opt., an ID uniquely identifying a transit agency, dataset unique "PAAC"
       agency_name varchar, -- full name of a transit agency
       agency_url varchar, -- transit agency URL
       agency_timezone varchar, -- a tz timezone name
       agency_lang varchar(2), -- opt., ISO 639-1 code for primary language of agency
       agency_phone varchar -- opt.,voice telephone number for an agency
);

CREATE TABLE g.stop (
       id serial PRIMARY KEY,
       stop_id varchar, -- an ID uniquely identifying a stop, dataset unique
       stop_code varchar, -- opt., unique stop identifier for display only
       stop_name varchar, -- name of a stop or station
       stop_desc varchar, -- opt., a description of the stop
       stop_lat float8,   -- latitude of a stop or station. a WGS 84 latitude
       stop_lon float8, -- longitude of a stop or station
       zone_id  varchar, -- opt., fare zone for a stop ID. used for providing fare info, referenced by fare_rule table
       stop_url varchar, -- opt., URL of a web page about a particular stop
       location_type integer, -- opt., 0/blank - Stop. 1 - Station
       stop_location POINT,
       parent_station varchar, -- opt., the stop ID of a station where this stop is located
       wheelchair_boarding integer
);

CREATE INDEX g_stop_stop_id_idx ON g.stop(stop_id);


CREATE TABLE g.route (
       id serial PRIMARY KEY,
       route_id varchar, -- ID uniquely identifying a route, dataset unique
       agency_id_id varchar, -- opt., references agency table 
       route_short_name varchar, -- e.g. 28X
       route_long_name varchar, -- full name of a route
       route_desc varchar, -- opt., description of the route
       route_type integer, -- light rail, subway,rail,bus, etc. see google transit site
       route_url varchar, -- opt., URL of a webpage about the route
       route_color varchar, -- opt., color corresponding to the route
       route_text_color varchar -- opt., legible color for text on route_color background
);

CREATE TABLE g.trip (
       id serial PRIMARY KEY,
       route_id varchar, -- references route table
       service_id varchar, -- unique ID for set of dates when service is available, refrences calendar and/or calendar_date tables
       trip_id varchar, -- an ID for a trip. dataset unique
       original_trip_id varchar,
       trip_headsign varchar, --opt., text for identifying a trip's destination to passengers
       trip_short_name varchar, -- opt., text identifying a trip that appears in schedules and sign boards
       direction_id integer, -- opt., binary value indicating direction of travel on bi-directional trips with the same route_id, name of direction is in trip_headsign
       block_id varchar, -- opt., for sequential trips that can be made by staying on the same vehicle, used by 2+ rows in trip
       shape_id varchar, -- opt., references shape table
       wheelchair_accessible integer
);

CREATE TABLE g.stop_time ( 
       id serial PRIMARY KEY,
       trip_id varchar, -- references trip table
       arrival_time varchar, -- arrival time at a stop on a route, can be greater than 24:00:00
       departure_time varchar, -- departure time from a stop on a route, can be greater than 24:00:00
       stop_id varchar, -- references stop table
       stop_sequence integer, -- non-negative increasing, order along trip
       stop_headsign varchar, -- opt., text identifying destination
       pickup_type integer, -- opt., 0-3, whether pickup is scheduled
       drop_off_type integer, -- opt., 0-3, whether dropoff is scheduled
       timepoint integer,
       incoming_point_polygon POLYGON,
       shape_dist_traveled float8 --opt., distance traveled from 1st shape point, units must match those in shape table
);

 -- This table lists periods of time that service is valid for.
 --
 --  start_date, end_date are in YYYYMMDD format
CREATE TABLE g.calendar (
       id serial PRIMARY KEY,       
       service_id varchar, -- id for set of dates when service available, referenced by trip table
       monday integer, -- is service valid for Mondays in date range, 0-no 1-yes
       tuesday integer, -- valid for Tuesdays?
       wednesday integer, -- valid for Wednesdays?
       thursday integer, -- valid for Thursdays?
       friday integer, -- valid for Fridays?
       saturday integer, -- valid for Saturdays?
       sunday integer, -- valid for Sundays?
       start_date date, -- service start date
       end_date date -- service end date, included in interval
);


 -- This table lists days that service is or isn't available, as exceptions
 -- to the calendar table.
CREATE TABLE g.calendar_date ( -- opt. 
       id serial PRIMARY KEY,
       service_id varchar, -- id for set of dates when service is available, referenced by trip table
       exception_date date, -- date when service availability differs from the norm, YYYYMMDD
       exception_type integer -- 1-service added on date, 2-service removed
);

CREATE TABLE g.fare_attribute ( 
       id serial PRIMARY KEY,
       fare_id varchar, -- unique ID for a fare class, dataset unique
       price varchar, -- fare price in units of currency type
       currency_type varchar, -- ISO 4217 currency code
       payment_method integer, -- 0-pay on board, 1-pay before boarding
       transfers integer, -- number of transfers permitted,0-2, unlimited if null
       transfer_duration varchar -- opt. time in seconds before transfer expires , 0 is how long a no transfer ticket is valid
);

 -- This table is used for specifying how fare_attribute rows 
 -- apply to an itinerary
CREATE TABLE g.fare_rule ( -- opt.
       id serial PRIMARY KEY,
       fare_id varchar, -- unique ID for a fare class, referenced from fare_attribute table
       route_id varchar, -- opt., references route table
       origin_id varchar, -- opt., references zone_id from stop table 
       destination_id varchar, -- opt., references zone_id from stop table
       contains_id varchar -- opt., associates fare_id with all itineraries passing through this zone_id from stop_table
);

CREATE TABLE g.shape ( -- ??? Do we need this?
       id serial PRIMARY KEY,
       shape_id varchar, -- unique id for a shape
       shape_pt_lat float8, -- shape point's latitude, valid WG 84 latitude
       shape_pt_lon float8, -- shape point's longitude, valid WG 84 longitude
       shape_pt_sequence varchar, -- sequence of point along shape, >0, increase along trip
       shape_dist_traveled float8 -- opt., real distance traveled from first shape point
);

 -- For schedules without a fixed list of stop times.
 --
 -- Times are in HH:MM:SS or H:MM:SS format, and can be greater than 24:00:00
 -- to show service continuing into the next day.
CREATE TABLE g.frequency ( -- opt.
       id serial PRIMARY KEY,
       trip_id varchar, -- ID identifying trip on which specified frequency of service applies, references trip table
       start_time varchar, -- time service begins with specified frequency
       end_time varchar, -- time a service changes to a different frequency or stops at first stop
       headway_secs varchar -- time between departures from same stop in seconds
);

 -- For additional rules about making connections between routes. 
CREATE TABLE g.transfer ( -- opt.
       id serial PRIMARY KEY, 
       from_stop_id varchar, -- stop ID where a connection between routes begins, references stop table
       to_stop_id varchar, -- stop ID where a connection between routes ends, references stop table
       transfer_type integer,--type of connection for specified pair, {0,empty}-3
       min_transfer_time integer --opt., seconds between arrival and departure
);

-- compute regression coefficients based on trace data
-- next line should be managed with the addition of new schedules

-- m.stop_time.id= 479582 appears broken after historical check
-- m.stop_time.id=  500034
-- check difference between arrival time and departure time as sanity check

-- assumption - this code is run nightly when buses are asleep

DROP SCHEMA IF EXISTS h CASCADE;
CREATE SCHEMA h;

-- some library functions

-- convert absolute goofy time (hours, minutes, seconds) to absolute goofy seconds
CREATE FUNCTION h.seconds(INTEGER, INTEGER, INTEGER) 
RETURNS REAL
AS 'SELECT (60.0*60.0*$1 + 60.0*$2 + $3)::REAL;'
LANGUAGE SQL
IMMUTABLE
RETURNS NULL ON NULL INPUT;

-- convert from absolute goofy seconds to absolute goofy time

CREATE FUNCTION h.to_hours(REAL)
RETURNS INTEGER
AS 'SELECT FLOOR($1/(60.0*60.0))::INTEGER;'
LANGUAGE SQL
IMMUTABLE
RETURNS NULL ON NULL INPUT;

CREATE FUNCTION h.to_minutes(REAL)
RETURNS INTEGER
AS 'SELECT FLOOR(($1::INTEGER % (60 * 60))/60)::INTEGER;'
LANGUAGE SQL
IMMUTABLE
RETURNS NULL ON NULL INPUT;

CREATE FUNCTION h.to_seconds(REAL)
RETURNS INTEGER
AS 'SELECT FLOOR(($1::INTEGER % 60))::INTEGER;'
LANGUAGE SQL
IMMUTABLE
RETURNS NULL ON NULL INPUT;


-- Given a non-goofy date and a goofy time (hours, minutes, seconds),
-- returns the equivalant goofy date.  (I.e., if the time is >= 24:00:00,
-- the goofy date is the day prior to the non-goofy date.)
-- This function is currently unused.
CREATE FUNCTION h.to_goofy_date(DATE, INTEGER, INTEGER, INTEGER)
RETURNS DATE
AS 'SELECT $1::DATE - FLOOR(h.seconds($2,$3,$4) / h.seconds(24,0,0))::INTEGER;'
LANGUAGE SQL
IMMUTABLE
RETURNS NULL ON NULL INPUT;


-- distance(lat1, lon1, lat2, lon2) - distance in meters
CREATE OR REPLACE FUNCTION h.distance(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION) 
RETURNS DOUBLE PRECISION
--AS 'SELECT (ACOS(SIN(RADIANS($1+ 0.0000001))*SIN(RADIANS($3 + 0.0000001)) + COS(RADIANS($1+ 0.0000001))*COS(RADIANS($3 + 0.0000001)) * COS(RADIANS($4 + 0.0000001) - RADIANS($2 + 0.0000001)))*6371000);'
AS 'SELECT 6371000.0 * SQRT(POWER((RADIANS($2) - RADIANS($4))*COS((RADIANS($1)+RADIANS($3))/2.0), 2) + POWER((RADIANS($1) - RADIANS($3)), 2));'
LANGUAGE SQL
IMMUTABLE
RETURNS NULL ON NULL INPUT;

-- h.trace is a modified copy of m.trace
CREATE TABLE h.trace (
    id SERIAL PRIMARY KEY,
        --session_id INTEGER,
        --session_record_counter INTEGER,
    agency_id INTEGER,
    trace_time_hour INTEGER,
    trace_time_minute INTEGER,
    trace_time_second INTEGER,
    trace_lat FLOAT8,
    trace_lon FLOAT8,
    trip_id VARCHAR,
    device_id VARCHAR,
    fullness FLOAT4,
    distance FLOAT4,
    stop_time_id INTEGER,   -- the id of stop_time
    stop_id VARCHAR,    -- the stop_id of this point in stop_time
    stop_sequence INTEGER,  -- the stop_sequence of this trip in stop_time
        trace_date DATE--,
    --processed_tag INTEGER DEFAULT 0 -- after the historical model finishes, this tag will be set to 1
);

CREATE INDEX trace_agency_id_trip_id_idx ON h.trace(agency_id, trip_id);

-- x axis is the distance to the stop
-- y axis is absolute goofy time in seconds
-- a are the previous stops to this estimate
-- st is the target stop
-- 
CREATE TABLE h.regress (
    agency_id INTEGER,
    trip_id VARCHAR,
    stop_time_id INTEGER,
    slope_spm REAL, -- seconds per meter
    intercept_time REAL,
    cnt INTEGER
);

-- process fullness 

CREATE TABLE h.fullness (
    agency_id INTEGER,
    stop_time_id INTEGER,
    trip_id VARCHAR,    -- trip_id is used by the real-time-model
    stop_sequence INTEGER,  -- stop_sequence is used by real-time-model
    estimate REAL,
    cnt INTEGER,
    PRIMARY KEY (agency_id, stop_time_id)
);

CREATE TABLE h.estimate (
    agency_id integer,
    trip_id character varying,
    stop_time_id integer,
    mph real,
    err_seconds real
);


-- do histogram analysis once per day
ANALYZE;

CREATE FUNCTION m.zeroint(text) RETURNS int AS 'SELECT CASE $1 WHEN '''' THEN 0 ELSE $1::int END;' LANGUAGE SQL;

CREATE FUNCTION m.goofy_hour(text) RETURNS int AS 'SELECT m.zeroint(split_part($1, '':'', 1));' LANGUAGE SQL;

CREATE FUNCTION m.goofy_minute(text) RETURNS int AS 'SELECT m.zeroint(split_part($1, '':'', 2));' LANGUAGE SQL;

--A log of Servlet calls made
CREATE TABLE m.call_log (
       id SERIAL PRIMARY KEY,
       date timestamp DEFAULT NOW(),
       device_id varchar,
       servlet_path varchar,
       url varchar,
       session_id integer,
       stat_timestamp timestamp DEFAULT NULL 
);


-- records a log of the trace signal emitted by users
CREATE TABLE m.trace (
       id SERIAL PRIMARY KEY,
       session_id INTEGER, -- generated session ids from client application
       session_record_counter INTEGER, -- trace counter for this client session
       agency_id INTEGER, -- cross reference to m.agency.id
       user_id INTEGER, -- cross reference to where?
       trace_lat FLOAT8, -- latitude of trace signal
       trace_lon FLOAT8, -- longitude of trace signal
       route_id INTEGER, -- the route the user claims she is on
       trip_id TEXT, -- the external trip the user claims she is on
       fullness FLOAT4, -- the claimed fullness of the bus she is on [0.0,1.0]
       trace_time_hour INTEGER, -- the hour of the signal, in goofy time
       trace_time_minute INTEGER, -- the minute of the signal, in goofy time
       trace_time_second INTEGER, -- the minute of the signal, in goofy time
       origin_id TEXT, --id of a stop the rider started from
       destination_id TEXT, -- id of the stop the rider indicated as a destination
       trace_date DATE, -- date trace was recorded
       device_id VARCHAR, -- a device unique identifier for the trace
       route_short_name VARCHAR, -- short name of the trip's route
       route_long_name VARCHAR, --long name of the trip's route
       current_points INTEGER, -- the rider's current available points
       total_points INTEGER, -- the rider's total accumulated points over all time
       vertical_accuracy FLOAT8, -- accuracy of lat/lon data in ???
       horizontal_accuracy FLOAT8, -- accuracy of position data in ???
       heading FLOAT8, -- heading of trace signal
       heading_accuracy FLOAT8, -- accuracy of heading data in degrees
       raw_heading_x FLOAT8, -- raw heading data on x-axis
       raw_heading_y FLOAT8, -- raw heading data on y-axis
       raw_heading_z FLOAT8, -- raw heading data on z-axis
       rotation_roll FLOAT8, -- rotation of the device around x-axis
       rotation_pitch FLOAT8, -- rotation of the device around y-axis
       rotation_yaw FLOAT8, -- rotation of the device around z-axis
       acceleration_x FLOAT8, -- acceleration value of the x-axis
       acceleration_y FLOAT8, -- acceleration value of the y-axis
       acceleration_z FLOAT8, -- acceleration value of the z-axis
       source VARCHAR, -- log where the trace comes from, from recording, from passed by or from not-got-on 
       stamp TIMESTAMP  DEFAULT NOW(), -- timestamp of insertion
       stat_timestamp timestamp DEFAULT NULL
);

CREATE INDEX m_trace_stamp_idx ON m.trace(stamp);

-- m.avl is the insertion point of agency-generated real-time data.  This
-- schema is based on a DB dump from Terence that he sent me (Charlie) 
-- for testing.
CREATE TABLE m.avl (
    id INTEGER PRIMARY KEY,
    agency_id INTEGER,
    avl_lat DOUBLE PRECISION,
    avl_lon DOUBLE PRECISION,
    vehicle_id INTEGER,
    route_id CHARACTER VARYING,
    destination_id INTEGER,
    avl_time_hour INTEGER,
    avl_time_minute INTEGER,
    avl_date DATE,
    route_short_name CHARACTER VARYING,
    stamp TIMESTAMP WITH TIME ZONE DEFAULT now(),
    block_ref VARCHAR, -- avl feed with block_ref <> '' indicates better location accuracy
    trip_id TEXT
);



-- Because we re-use the same queues and process for user-generated real-time
-- data and agency-generated real-time data, rows in the m.avl table and 
-- m.trace tables need distinct ids. 
ALTER TABLE ONLY m.avl ALTER COLUMN id SET DEFAULT nextval('m.trace_id_seq'::regclass);

CREATE INDEX m_avl_stamp_idx ON m.avl(stamp);

CREATE TABLE m.avl_pred (
    id SERIAL NOT NULL,
    agency_id INTEGER,
    type VARCHAR,
    stop_id VARCHAR NOT NULL,
    vehicle_id INTEGER,
    distance_to_stop DOUBLE PRECISION,
    route_id CHARACTER VARYING,
    minute_left_to_stop INTEGER,
    trip_id TEXT,
    predict_time_hour INTEGER NOT NULL,
    predict_time_minute INTEGER NOT NULL,
    predict_time_second INTEGER NOT NULL,
    prediction_timestamp TIMESTAMP WITH TIME ZONE,
    stamp TIMESTAMP WITH TIME ZONE DEFAULT now()
);

ALTER TABLE m.avl_pred OWNER TO postgres;

CREATE INDEX m_avl_pred_stop_id_trip_id on m.avl_pred(stop_id, trip_id);

CREATE TABLE m.avl_pred_history (LIKE m.avl_pred);
ALTER TABLE m.avl_pred_history OWNER TO postgres;

CREATE FUNCTION m.copy_avl_pred_to_avl_pred_history() RETURNS TRIGGER AS 
$copy_avl_pred_to_avl_pred_history$
    BEGIN
        INSERT INTO m.avl_pred_history (id,
                                        agency_id,
                                        type,
                                        stop_id,
                                        vehicle_id,
                                        distance_to_stop,
                                        route_id,
                                        minute_left_to_stop,
                                        trip_id,
                                        predict_time_hour,
                                        predict_time_minute,
                                        predict_time_second,
                                        prediction_timestamp,
                                        stamp)
            SELECT NEW.id, 
                   NEW.agency_id,
                   NEW.type, 
                   NEW.stop_id, 
                   NEW.vehicle_id,
                   NEW.distance_to_stop,
                   NEW.route_id,
                   NEW.minute_left_to_stop,
                   NEW.trip_id,
                   NEW.predict_time_hour,
                   NEW.predict_time_minute,
                   NEW.predict_time_second,
                   NEW.prediction_timestamp,
                   NEW.stamp;
        RETURN NULL;
    END;
$copy_avl_pred_to_avl_pred_history$
LANGUAGE PLPGSQL;

CREATE TRIGGER copy_avl_pred_to_avl_pred_history_trigger
  AFTER INSERT ON m.avl_pred
  FOR EACH ROW EXECUTE PROCEDURE m.copy_avl_pred_to_avl_pred_history();

-- Data from m.trace and m.avl are copied (with minimal processing) to
-- m.real_time_queue and m.recent_historical_traces for processing
-- when the real-time or historical model is run.
--
-- m.recent_historical_traces generally contains traces for the past
-- 30 days, and is pruned when the historical model runs.
--
-- m.real_time_queue contains new traces since the last time the 
-- real-time model ran, and is emptied each time the real-time model runs.
-- 
-- device_id and fullness are NULL for agency-generated AVL data.

CREATE TABLE m.real_time_queue (
       id INTEGER PRIMARY KEY,
       agency_id INTEGER, -- cross reference to m.agency.id
       trace_lat FLOAT8, -- latitude of trace signal
       trace_lon FLOAT8, -- longitude of trace signal
       trip_id TEXT, -- the external trip the user claims she is on
       fullness FLOAT4, -- the claimed fullness of the bus she is on [0.0,1.0]
       trace_time_hour INTEGER, -- the hour of the signal, in goofy time
       trace_time_minute INTEGER, -- the minute of the signal, in goofy time
       trace_time_second INTEGER, -- the minute of the signal, in goofy time
       trace_date DATE, -- date trace was recorded
       device_id VARCHAR,  -- device that generated trace, null for AVL
       stamp TIMESTAMP  DEFAULT NOW(),-- timestamp of insertion
       historical_tag integer DEFAULT 0
);

CREATE INDEX m_real_time_queue_agency_id_trip_id_idx ON m.real_time_queue (agency_id, trip_id);
--CREATE INDEX m_real_time_queue_agency_id_idx ON m.real_time_queue USING btree (agency_id);
CREATE INDEX m_real_time_queue_trip_id_idx ON m.real_time_queue USING btree (trip_id);

CREATE TABLE m.recent_historical_traces (LIKE m.real_time_queue);
CREATE INDEX m_recent_historical_traces_stamp_idx 
    ON m.recent_historical_traces(stamp);
CREATE INDEX m_recent_historical_traces_agency_id_idx ON m.recent_historical_traces USING btree (agency_id, id);

CREATE TABLE m.user_stop_history (
       id serial PRIMARY KEY,
       device_id varchar,
       agency_id INTEGER,
       stop_id varchar, 
       latitude float4, 
       longitude float4,
       time_selected timestamp default now());

CREATE INDEX user_stop_index ON m.user_stop_history USING btree (device_id, stop_id);

CREATE TABLE m.user_recommended_route (
       device_id character varying,
       stop_id character varying,
       hour integer
);

CREATE INDEX stop_recommend_index ON m.user_recommended_route USING btree (device_id, hour);

-- The trigger function and definition that copies new rows from m.trace
-- into m.recent_historical_traces and m.real_time_queue
CREATE FUNCTION m.copy_user_trace_into_queues() RETURNS TRIGGER AS 
$copy_user_trace_into_queues$
    BEGIN
        INSERT INTO m.recent_historical_traces (id,
                                                agency_id,
                                                trace_lat,
                                                trace_lon,
                                                trip_id,
                                                fullness,
                                                trace_time_hour,
                                                trace_time_minute,
                                                trace_time_second,
                                                trace_date,
                                                device_id,
                                                stamp,
                                            historical_tag)
            SELECT NEW.id, NEW.agency_id, NEW.trace_lat, NEW.trace_lon,
                   NEW.trip_id, NEW.fullness, NEW.trace_time_hour,
                   NEW.trace_time_minute, NEW.trace_time_second,
                   NEW.trace_date, NEW.device_id, NEW.stamp, 0
        WHERE NEW.source <>'cancel';
        INSERT INTO m.real_time_queue (id,
                                       agency_id,
                                       trace_lat,
                                       trace_lon,
                                       trip_id,
                                       fullness,
                                       trace_time_hour,
                                       trace_time_minute,
                                       trace_time_second,
                                       trace_date,
                                       device_id,
                                       stamp)
            SELECT NEW.id, NEW.agency_id, NEW.trace_lat, NEW.trace_lon,
                   NEW.trip_id, NEW.fullness, NEW.trace_time_hour,
                   NEW.trace_time_minute, NEW.trace_time_second,
                    NEW.trace_date, NEW.device_id, NEW.stamp
         WHERE NEW.source <>'cancel';
        RETURN NULL;
    END;
$copy_user_trace_into_queues$
LANGUAGE PLPGSQL;

CREATE TRIGGER copy_user_trace_into_queues_trigger
  AFTER INSERT ON m.trace
  FOR EACH ROW EXECUTE PROCEDURE m.copy_user_trace_into_queues();



-- The trigger function and definition that copies new rows from m.avl
-- into m.recent_historical_traces and m.real_time_queue
CREATE FUNCTION m.copy_avl_trace_into_queues() RETURNS TRIGGER AS 
$copy_avl_trace_into_queues$
    BEGIN
        INSERT INTO m.recent_historical_traces (id,
                                                agency_id,
                                                trace_lat,
                                                trace_lon,
                                                trip_id,
                                                fullness,
                                                trace_time_hour,
                                                trace_time_minute,
                                                trace_time_second,
                                                trace_date,
                                                device_id,
                                                stamp)
            SELECT NEW.id, NEW.agency_id, NEW.avl_lat, NEW.avl_lon,
                   NEW.trip_id, NULL, NEW.avl_time_hour,  -- null fullness data
                   NEW.avl_time_minute, 0,  -- 0 seconds
                   NEW.avl_date, NULL, NEW.stamp;  -- null device_id
        INSERT INTO m.real_time_queue (id,
                                       agency_id,
                                       trace_lat,
                                       trace_lon,
                                       trip_id,
                                       fullness,
                                       trace_time_hour,
                                       trace_time_minute,
                                       trace_time_second,
                                       trace_date,
                                       device_id,
                                       stamp)
            SELECT NEW.id, NEW.agency_id, NEW.avl_lat, NEW.avl_lon,
                   NEW.trip_id, NULL, NEW.avl_time_hour,  -- null fullness data
                   NEW.avl_time_minute, 0,  -- 0 seconds
                   NEW.avl_date, NULL, NEW.stamp;  -- null device_id
        RETURN NULL;
    END;
$copy_avl_trace_into_queues$
LANGUAGE PLPGSQL;

CREATE TRIGGER copy_avl_trace_into_queues_trigger
  AFTER INSERT ON m.avl
  FOR EACH ROW EXECUTE PROCEDURE m.copy_avl_trace_into_queues();



CREATE TABLE m.agency (
       agency_id INTEGER PRIMARY KEY,
       agency_id_id VARCHAR, -- opt., an ID uniquely identifying a transit agency, dataset unique
       agency_name VARCHAR, -- full name of a transit agency
       agency_url VARCHAR, -- transit agency URL
       agency_timezone VARCHAR, -- a tz timezone name
       agency_lang VARCHAR(2), -- opt., ISO 639-1 code for primary language of agency
       agency_phone VARCHAR, -- opt.,voice telephone number for an agency
       region_id INTEGER, -- the region id of this integer
       valid_now INTEGER,  -- 1 means the current GTFS version is effective now, 0 means not effective now  
       avl_agency_name VARCHAR, 
       avl_api_url VARCHAR,
       avl_api_key VARCHAR,
       avl_table_name VARCHAR,
       show_in_out BOOLEAN, -- true means ins and outs should be shown in nearby stops on client, false if otherwise
       user_id INTEGER
);

CREATE TABLE m.stop (
       id serial PRIMARY KEY,
       agency_id INTEGER,
       stop_id VARCHAR, -- an ID uniquely identifying a stop, dataset unique
       stop_code VARCHAR, -- opt., unique stop identifier for display only
       stop_name VARCHAR, -- name of a stop or station
       stop_desc VARCHAR, -- opt., a description of the stop
       stop_lat FLOAT8,   -- latitude of a stop or station. a WGS 84 latitude
       stop_lon FLOAT8, -- longitude of a stop or station
       stop_location POINT, -- a lat/lon point of the stop's location
       stop_location_box BOX, -- a box around the stop's location, for filtering when finding the stop nearest to a trace point
       zone_id  VARCHAR, -- opt., fare zone for a stop ID. used for providing fare info, referenced by fare_rule table
       stop_url VARCHAR, -- opt., URL of a web page about a particular stop
       location_type INTEGER, -- opt., 0/blank - Stop. 1 - Station
       parent_station VARCHAR, -- opt., the stop ID of a station where this stop is located
       wheelchair_boarding INTEGER
);

CREATE INDEX m_stop_agency_id_stop_id_idx ON m.stop USING btree (agency_id, stop_id);
--CREATE INDEX m_stop_agency_id_idx ON m.stop USING btree (agency_id);
CREATE INDEX m_stop_stop_id_idx ON m.stop USING btree (stop_id);
CREATE INDEX m_stop_agency_id_stop_lat_idx ON m.stop USING btree (agency_id, stop_lat DESC);
CREATE INDEX m_stop_agency_id_stop_lon_idx ON m.stop USING btree (agency_id, stop_lon DESC);
CREATE INDEX m_stop_stop_location_box_idx ON m.stop USING gist (stop_location_box);


CREATE TABLE m.route (
       id serial PRIMARY KEY,
       route_id VARCHAR, -- ID uniquely identifying a route, dataset unique
       agency_id INTEGER, -- ID served as a GTFS version reference number
       agency_id_id VARCHAR, -- opt., references agency table, part of GTFS standard, not internal agency id
       route_short_name VARCHAR, -- e.g. 28X
       route_long_name VARCHAR, -- full name of a route
       route_desc VARCHAR, -- opt., description of the route
       route_type INTEGER, -- light rail, subway,rail,bus, etc. see google transit site
       route_url VARCHAR, -- opt., URL of a webpage about the route
       route_color VARCHAR, -- opt., color corresponding to the route
       route_text_color VARCHAR -- opt., legible color for text on route_color background
);

CREATE INDEX m_route_agency_id_idx ON m.route USING btree (agency_id);
CREATE INDEX m_route_agency_id_route_id_idx ON m.route USING btree (agency_id, route_id);

CREATE TABLE m.trip (
       id serial PRIMARY KEY,
       route_id VARCHAR, -- references route table
       service_id VARCHAR, -- unique ID for set of dates when service is available, refrences calendar and/or calendar_date tables
       trip_id VARCHAR, -- an ID for a trip. dataset unique
       trip_headsign VARCHAR, --opt., text for identifying a trip's destination to passengers
       trip_short_name VARCHAR, -- opt., text identifying a trip that appears in schedules and sign boards
       direction_id INTEGER, -- opt., binary value indicating direction of travel on bi-directional trips with the same route_id, name of direction is in trip_headsign
       block_id VARCHAR, -- opt., for sequential trips that can be made by staying on the same vehicle, used by 2+ rows in trip
       shape_id VARCHAR, -- opt., references shape table
       agency_id INTEGER, -- foreign key to m.agency.id (and not m.agency.agency_id)
       wheelchair_accessible integer
);

CREATE INDEX m_trip_agency_id_idx ON m.trip USING btree (agency_id);
CREATE INDEX m_trip_agency_id_route_id_idx ON m.trip USING btree (agency_id, route_id DESC);
CREATE INDEX m_trip_agency_id_service_id_idx ON m.trip USING btree (agency_id, service_id DESC);
CREATE INDEX m_trip_id_agency_id_trip_id_idx ON m.trip USING btree (agency_id, trip_id);

CREATE TABLE m.stop_time ( 
    id serial PRIMARY KEY,
    agency_id INTEGER,
    trip_id VARCHAR, -- references trip table
    -- arrival time at a stop on a route
    arrival_time_hour INTEGER, -- goofy hour
    arrival_time_minute INTEGER, -- goofy minute
-- arrival_error FLOAT4, -- at 90% level +- this error in minutes 
    -- departure time from a stop on a route
    departure_time_hour INTEGER, -- goofy hour
    departure_time_minute INTEGER, -- goofy minute
-- departure_error FLOAT4, -- 90% level +- this error in minutes
    estimate_source m.source_type, -- source of time estimate
    fullness FLOAT4 DEFAULT null, -- bus is by default null load information
        incoming_point_polygon POLYGON, -- used to determine if a trace-point is approaching a stop on a trip
    stop_id VARCHAR, -- references stop table
    stop_sequence INTEGER, -- non-negative increasing, order along trip
    stop_headsign VARCHAR, -- opt., text identifying destination
    pickup_type INTEGER, -- opt., 0-3, whether pickup is scheduled
    drop_off_type INTEGER, -- opt., 0-3, whether dropoff is scheduled
    shape_dist_traveled FLOAT8 --opt., distance traveled from 1st shape point, units must match those in shape table
);

CREATE INDEX m_stop_time_agency_id_estimate_source_idx ON m.stop_time USING btree (agency_id, estimate_source);
CREATE INDEX m_stop_time_agency_id_fullness_idx ON m.stop_time USING btree (agency_id, fullness);
--CREATE INDEX m_stop_time_fullness_idx ON m.stop_time USING btree (fullness);
CREATE INDEX m_stop_time_agency_id_idx ON m.stop_time USING btree (agency_id);
CREATE INDEX m_stop_time_agency_id_stop_id_idx ON m.stop_time USING btree (agency_id, stop_id DESC);
CREATE INDEX m_stop_time_agency_id_trip_id_idx ON m.stop_time USING btree (agency_id, trip_id);

CREATE TABLE m.calendar (
       id serial PRIMARY KEY,       
       agency_id INTEGER, -- id referenced as a GTFS version number
       service_id VARCHAR, -- id for set of dates when service available, referenced by trip table
       monday INTEGER, -- is service valid for Mondays in date range, 0-no 1-yes
       tuesday INTEGER, -- valid for Tuesdays?
       wednesday INTEGER, -- valid for Wednesdays?
       thursday INTEGER, -- valid for Thursdays?
       friday INTEGER, -- valid for Fridays?
       saturday INTEGER, -- valid for Saturdays?
       sunday INTEGER, -- valid for Sundays?
       start_date DATE, -- service start date
       end_date DATE -- service end date, included in interval
);

CREATE TABLE m.calendar_date ( -- opt. 
       id serial PRIMARY KEY,
       agency_id INTEGER, -- id referenced as a GTFS version number 
       service_id VARCHAR, -- id for set of dates when service is available, referenced by trip table
       exception_date DATE, -- date when service availability differs from the norm, YYYYMMDD
       exception_type INTEGER -- 1-service added on date, 2-service removed
);

-- system wide tables for organizing agencies into regions
-- m.region is the list of regions
CREATE TABLE m.region (
       region_id INTEGER PRIMARY KEY, -- not a serial, i.e. we manage
       region_name VARCHAR, -- e.g. "US, PA, Pittsburgh"
       region_server VARCHAR -- "http://tiramisu.apt.ri.cmu.edu:8080/dv1/server"
);
-- m.region_agency 
CREATE TABLE m.region_agency (
       agency_id_id VARCHAR PRIMARY KEY, -- e.g., "PAAC"
       agency_id INTEGER, -- unique across all agencies
       region_id INTEGER, -- e.g. "1"
       agency_directory VARCHAR, -- directory name data e.g. "paac-pittsburgh-pa"
       agency_lat FLOAT8,
       agency_lon FLOAT8
);

-- m.status -- the user status
CREATE TABLE m.status (
    id SERIAL PRIMARY KEY,
    agency_id INTEGER,  -- reference m.agency table
    session_id INTEGER, -- session id for user on device
    device_id VARCHAR,  -- unique device id
    old_id VARCHAR, 
    os_version character varying,   -- device model and ios version 
    schedulecount INTEGER,  -- number of schedule impressions
    historicalcount INTEGER,    -- number of historical impressions
    realtimecount INTEGER,  -- number of real-time impressions
    recordcount INTEGER,    -- number of records (session granularity)
    usecount INTEGER,   -- number of uses (session granularity)
    recordpoint INTEGER,    -- value of record for restricted 
    usepoint INTEGER,   -- value of use for restricted
    recordingtime INTEGER,  -- number of minutes in recording
    pointcategory INTEGER, -- 0-5 determined by mod on device id
    restricted BOOLEAN, -- in violation of category
    ad_category integer, -- advertisement category
    app_version varchar, -- app version number 
    voice_over BOOLEAN,  -- if user turns on voice over 
    stamp TIMESTAMP DEFAULT NOW() -- timestamp of insertion
);


-- Contains a single row for each agency_id/stop_time_id for both the
-- schedule and historical models, but not for the real-time model.
-- The real-time model currently assumes that m.estimate will not
-- contain real-time data.
CREATE TABLE m.estimate (
    agency_id INTEGER,      -- reference m.stop_time.agency_id
    stop_time_id INTEGER,       -- reference m.stop_time.id
    intercept_time REAL,    -- goofy seconds from midnight
    estimate_source m.source_type
);

CREATE INDEX m_estimate ON m.estimate USING btree (agency_id, stop_time_id);
CREATE INDEX m_estimate_intercept_time ON m.estimate USING btree (agency_id, intercept_time);
CREATE INDEX m_estimate_estimate_source ON m.estimate USING btree (agency_id, estimate_source);


-- m.best_estimate contains a single row for each agency_id/stop_time_id
-- using the best estimate type for which we've got a row in m.estimate.
-- Note that this depends on Postgresql ENUM ordering for m.source_type.
-- This exists as a bit of a hack; m.best_estimate mimics an older 
-- version of m.estimate that contained just a single row per 
-- agency_id/stop_time_id.
CREATE VIEW m.best_estimate AS 
  SELECT e.agency_id, 
        e.stop_time_id, 
        e.intercept_time, 
        e.estimate_source 
     FROM ((SELECT m.estimate.agency_id, 
          m.estimate.stop_time_id, 
          max(m.estimate.estimate_source) AS estimate_source FROM m.estimate 
          GROUP BY m.estimate.agency_id, m.estimate.stop_time_id) best  -- alias needed for natural join
     NATURAL JOIN m.estimate e);


-- Contains a single row for each agency_id/stop_time_id for all three 
-- of the schedule, historical, and real-time models.
-- We might not be using these tables currently, but probably will in
-- the future.
CREATE TABLE m.fullness_estimate (
    agency_id INTEGER,              -- reference m.stop_time.agency_id
    stop_time_id INTEGER,           -- reference m.stop_time.id
    fullness REAL,                  -- fraction from 0.0 to 1.0
    estimate_source m.source_type
);

CREATE INDEX m_fullness_estimate ON m.fullness_estimate USING btree (agency_id, stop_time_id);


-- m.best_fullness_estimate contains a single row for 
-- each agency_id/stop_time_id using the best estimate type for 
-- which we've got a row in m.fullness_estimate.
-- Note that this depends on Postgresql ENUM ordering for m.source_type.
CREATE VIEW m.best_fullness_estimate AS 
  SELECT e.agency_id,
        e.stop_time_id, 
        e.fullness, 
        e.estimate_source 
     FROM ((SELECT m.fullness_estimate.agency_id, 
               m.fullness_estimate.stop_time_id, 
               max(m.fullness_estimate.estimate_source) AS estimate_source 
               FROM m.fullness_estimate 
               GROUP BY m.fullness_estimate.agency_id, m.fullness_estimate.stop_time_id) best 
     NATURAL JOIN m.fullness_estimate e);

-- This table stores the nearest stop for a given trace record.
-- Data is inserted into this table during the real-time model,
-- and used by both the real-time and historical models.
--
-- We're currently not enforcing the foreign key constraints, but
-- I've put in their specification in case we start enforcing them later.
CREATE TABLE m.nearest_stop (
    trace_id INTEGER PRIMARY KEY, -- REFERENCES m.trace(id)
                                  --   ON UPDATE CASCADE
                                  --   ON DELETE CASCADE,
    stop_time_id INTEGER, -- REFERENCES m.stop_time(id),
    stop_id VARCHAR, 
    stop_sequence integer,
    stamp TIMESTAMP
);

CREATE INDEX m_nearest_stop_stamp_idx ON m.nearest_stop USING btree (stamp DESC);
CREATE INDEX m_nearest_stop_stop_id_idx ON m.nearest_stop USING btree (stop_id);

CREATE TABLE m.historical_nearest_stop (
       trace_id INTEGER,
       stop_time_id INTEGER,
       stop_id character varying,
       stop_sequence INTEGER,
       stamp timestamp without time zone
);

CREATE INDEX m_historical_nearest_stop_stop_id_idx ON m.historical_nearest_stop USING btree (stop_id);

CREATE TABLE m.shape(
  id SERIAL,
  agency_id INTEGER NOT NULL,
  trip_id VARCHAR NOT NULL,
  shape_id VARCHAR NOT NULL,
  shape_sequence INTEGER NOT NULL,
  
  shape_lat DOUBLE PRECISION NOT NULL,
  shape_lon DOUBLE PRECISION NOT NULL,

  stop_id VARCHAR,
  --intercept_time DOUBLE PRECISION NOT NULL,

  prev_stop_id VARCHAR,
  distance_from_prev_stop DOUBLE PRECISION,
  sequence_from_prev_stop INTEGER,
  --prev_stop_intercept_time DOUBLE PRECISION,

  next_stop_id VARCHAR,
  distance_to_next_stop DOUBLE PRECISION,
  sequence_to_next_stop INTEGER
  --next_stop_intercept_time DOUBLE PRECISION
);

CREATE INDEX m_shape_agency_id_trip_id_index on m.shape(agency_id, trip_id);

CREATE TABLE m.nearest_shape(
  trace_id INTEGER PRIMARY KEY,
  shape_id INTEGER, -- REFERENCE m.shape(id)
  distance DOUBLE PRECISION
);

CREATE TABLE m.ad_click_record (
        id SERIAL PRIMARY KEY,
        agency_id INTEGER,      -- reference m.agency table
        session_id INTEGER,     -- session id for user on device
        device_id VARCHAR,      -- unique device id
        click_time DATE,        -- date ad was clicked
        ad_category INTEGER,    -- ad category
        page    VARCHAR,        -- page when ad was clicked
        favorite VARCHAR,       -- if this comes from favorites
        stamp TIMESTAMP DEFAULT NOW() -- timestamp of insertion
);

CREATE TYPE m.note_filter_type AS ENUM('stop', 'route');

CREATE TABLE m.note_filter_log (
       device_id VARCHAR,
       filter_type m.note_filter_type,
       filter_value VARCHAR,
       stamp TIMESTAMP
);

CREATE TABLE m.screen_log (
       device_id VARCHAR,
       screen m.client_screen,
       stamp TIMESTAMP
);

CREATE TYPE m.client_state_type AS ENUM('background', 'started', 'foreground');

CREATE TABLE m.app_state_log (
       device_id VARCHAR,
       state_type m.client_state_type,
       stamp TIMESTAMP
);

CREATE TABLE m.stop_view_log (
       device_id VARCHAR,
       agency_id INTEGER,
       stop_id VARCHAR,
       favorite BOOLEAN,
       stamp TIMESTAMP
);

-- The following tables are simply a copy of tables used in real_time_simulation(just schema)
CREATE TABLE r.trace_sim (LIKE r.trace);
CREATE INDEX "trace_sim_pkey" ON r.trace_sim  (id);
CREATE INDEX "r_trace_sim_agency_id_stop_time_id_idx"ON r.trace_sim  (agency_id, stop_time_id);
CREATE INDEX "r_trace_sim_agency_id_trip_id_idx" ON r.trace_sim (agency_id, trip_id);


CREATE TABLE r.error_sim (LIKE r.error);
CREATE INDEX "r_error_sim_agency_id_stop_time_id_idx" on r.error_sim (agency_id, stop_time_id);


CREATE TABLE r.fullness_sim (LIKE r.fullness);
CREATE INDEX "fullness_sim_pkey" on r.fullness_sim (agency_id, stop_time_id);


CREATE TABLE m.real_time_queue_sim (LIKE m.real_time_queue);
CREATE INDEX "real_time_queue_sim_pkey" ON m.real_time_queue_sim (id);
CREATE INDEX "m_real_time_queue_sim_agency_id_idx" ON m.real_time_queue_sim (agency_id);
CREATE INDEX "m_real_time_queue_sim_trip_id_idx" ON m.real_time_queue_sim (trip_id);

CREATE TABLE m.nearest_stop_sim (LIKE m.nearest_stop);
CREATE INDEX "nearest_stop_sim_pkey" ON m.nearest_stop_sim (trace_id);
CREATE INDEX "m_nearest_stop_sim_stop_id_idx" ON m.nearest_stop_sim (stop_id);


CREATE TABLE m.stop_time_sim (LIKE m.stop_time);

CREATE INDEX "stop_time_sim_pkey" ON m.stop_time_sim (id);
CREATE INDEX "m_stop_time_sim_agency_id_estimate_source_idx" ON m.stop_time_sim (agency_id, estimate_source);
CREATE INDEX "m_stop_time_sim_agency_id_fullness_idx" ON m.stop_time_sim (agency_id, fullness);
CREATE INDEX "m_stop_time_sim_agency_id_idx" ON m.stop_time_sim (agency_id);
CREATE INDEX "m_stop_time_sim_agency_id_stop_id_idx" ON m.stop_time_sim (agency_id, stop_id DESC);
CREATE INDEX "m_stop_time_sim_agency_id_trip_id_idx" ON m.stop_time_sim (agency_id, trip_id);
CREATE INDEX "m_stop_time_sim_fullness_idx" ON m.stop_time_sim (fullness);

CREATE TYPE m.realtime_coverage_source_type AS ENUM('manual', 'automatic');
CREATE TABLE m.realtime_coverage_statistic(
    id SERIAL,
    agency_id INTEGER,
    realtime_count INTEGER,
    total_count INTEGER,
    record_source m.realtime_coverage_source_type,
    record_cover_range INTEGER,
    stamp TIMESTAMP WITH TIME ZONE DEFAULT now()
);

ALTER TABLE r.trace_sim OWNER TO postgres;
ALTER TABLE r.error_sim OWNER TO postgres;
ALTER TABLE r.fullness_sim OWNER TO postgres;
ALTER TABLE m.real_time_queue_sim OWNER TO postgres;
ALTER TABLE m.nearest_stop_sim OWNER TO postgres;
ALTER TABLE m.stop_time_sim OWNER TO postgres;
ALTER TABLE m.realtime_coverage_statistic OWNER TO postgres;


-- debugging views

CREATE VIEW r.stop_time_name AS
    SELECT st.trip_id, s.stop_name, r.route_short_name, r.route_long_name, st.stop_sequence 
    FROM m.stop_time st, m.stop s, m.trip t, m.route r
    WHERE st.estimate_source >= 'real-time-user'
    AND s.stop_id = st.stop_id
    AND st.trip_id = t.trip_id
    AND t.route_id = r.route_id
    ORDER BY st.stop_sequence ASC;

CREATE VIEW r.trace_regress_stop_time AS
    SELECT st.agency_id, st.trip_id, st.id, COUNT(*)
      FROM r.trace r, h.regress h, m.stop_time st
     WHERE r.agency_id = h.agency_id
       AND r.trip_id = h.trip_id
       AND r.trip_id = st.trip_id
       AND r.stop_sequence < st.stop_sequence
       AND st.stop_sequence - r.stop_sequence < 20
      GROUP BY st.agency_id, st.trip_id, st.id;

CREATE VIEW r.trace_trip_regress AS
    SELECT h.agency_id, h.trip_id, h.stop_time_id, COUNT(*)
      FROM r.trace r, h.regress h
     WHERE r.agency_id = h.agency_id
       AND r.stop_time_id = h.stop_time_id
      GROUP BY h.agency_id, h.trip_id, h.stop_time_id
      ORDER BY h.agency_id, h.trip_id, h.stop_time_id;

CREATE VIEW r.trace_stop_name AS
    SELECT r.id, s.stop_name
    FROM r.trace r, m.stop s
    WHERE r.stop_id = s.stop_id;

CREATE VIEW r.trace_distance AS
    SELECT DISTINCT t.id as id, t.trace_lat, t.trace_lon, t.trip_id, a.id as a_id, a.stop_id, a.stop_sequence as seq, ROUND(h.distance(s.stop_lat, s.stop_lon, t.trace_lat, t.trace_lon))
    FROM r.trace t, m.stop_time st, m.stop_time a, m.stop s
    WHERE t.trip_id = st.trip_id
      AND t.agency_id = st.agency_id
--    AND t.stamp > NOW() - interval '1 minute'
      AND t.trip_id = a.trip_id
      AND s.stop_id = a.stop_id
    ORDER BY t.id;
