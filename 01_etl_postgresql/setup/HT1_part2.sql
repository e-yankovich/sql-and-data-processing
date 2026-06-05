/*
Use the script HT1_part_2.sql to add a new set of data to the Staging table. 
*/

insert into Staging_Gym_visit
	(visit_date, gym_code, personal_code, visitor_name, time_in, time_out)
values
	('2025-04-04', 'Gym_1', 'P3', 'L3 F3', '19:45', '21:15'),
	('2025-04-04', 'Gym_2', 'P5', 'F5 L5', null, '10:40'),
	('2025-04-05', 'Gym_1', 'P1', 'L1 F1', '16:00', '17:00');