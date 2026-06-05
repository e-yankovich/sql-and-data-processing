/*
Use the script from the file HT1_part1.sql to create the DWH tables and the staging table. 
Populate the Dim_Gym and Dim_Member tables, and add initial data to the Staging table.
*/

drop table if exists Fact_Visit;
drop table if exists Dim_Member;
drop table if exists Dim_Gym;
drop table if exists Dim_Date;
drop table if exists Staging_Gym_visit;
drop type if exists day_part_enum;

create table Dim_Member(
	member_id serial primary key,
	personal_code text not null unique,
	last_name text not null,
	first_name text not null
);

create table Dim_Gym(
	gym_id serial primary key,
	gym_code text not null unique
);

create table Dim_Date(
	date_key date primary key,	
	day_number_of_month int not null,
	month_number_of_year int not null,
	year_number int not null,
	day_name text not null,
	month_name text not null	
);

create type day_part_enum as enum ('Morning', 'Day', 'Evening');

create table Fact_Visit(
	visit_id serial primary key,
	gym_id int not null references Dim_Gym(gym_id),
	member_id int not null references Dim_Member(member_id),
	visit_date_key date not null references Dim_Date(date_key),
	visit_duration int not null,
	day_part day_part_enum not null
);

create table Staging_Gym_visit(
	v_id serial primary key,
	visit_date date,
	gym_code text,
	personal_code text,
	visitor_name text,
	time_in time,
	time_out time,
	require_manual_processing int default 0
);

insert into Dim_Gym(gym_code) 
values
	('Gym_1'), 
	('Gym_2');

insert into Dim_Member(personal_code, last_name, first_name) 
values
	('P1', 'L1', 'F1'),
	('P2', 'L2', 'F2'),
	('P3', 'L3', 'F3'),
	('P4', 'L4', 'F4'),
	('P5', 'L5', 'F5'),
	('P6', 'L6', 'F6');

insert into Staging_Gym_visit
	(visit_date, gym_code, personal_code, visitor_name, time_in, time_out)
values
	('2025-04-01', 'Gym_1', 'P1', 'L1 F1', '15:00', '13:00'),
	('2025-04-03', 'Gym_1', 'P1', 'L1 F1', '16:00', '17:00'),
	('2025-04-03', 'Gym_1', 'P1', 'L1 F1', '16:00', '17:00'),
	('2025-04-04', 'Gym_1', 'P2', 'L2 F2', '16:20', '18:10'),
	('2025-04-04', 'Gym_1', 'P3', 'L3 F3', '19:45', null),
	('2025-04-04', 'Gym_1', 'P4', 'L4 F4', '16:00', '15:00'),
	('2025-04-02', 'Gym_1', 'P3', 'L1 F1', '8:20', '9:30'),
	('2025-04-03', 'Gym_2', 'P5', 'F5 L5', '7:20', null),	
	('2025-04-03', 'Gym_2', 'P5', 'F5 L5', null, '8:20'),
	('2025-04-04', 'Gym_2', 'P6', 'F6 L6', '18:30', null),	
	('2025-04-04', 'Gym_2', 'P6', 'F6 L6', null, '19:50'),
	('2025-04-04', 'Gym_2', 'P5', 'F5 L5', '9:30', null),	
	('2025-04-01', 'Gym_1', 'P1', null, '7:00', '8:00');