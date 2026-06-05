# SQL & Data Processing

A collection of assignments completed as part of a SQL and Data Processing course, covering relational databases, ETL pipelines, NoSQL databases, and data visualization.

---

## 01 — ETL Pipeline (PostgreSQL)

An ETL process that transfers gym visit data from a Staging table to a Data Warehouse.

**Key tasks:**
- Populating the `Dim_Date` table
- Handling data inconsistencies: missing values, duplicates, conflicting name formats between gyms
- Merging split records (Gym_2 stores check-in and check-out as separate rows)
- Validating that `personal_code` matches the visitor's name
- Calculating visit duration and time-of-day category (Morning / Day / Evening)
- Loading clean records into `Fact_Visit` and flagging problematic rows for manual review

**Stack:** PostgreSQL

> Setup scripts (`HT1_part1.sql`, `HT1_part2.sql`) were provided as part of the course assignment.

---

## 02 — Tic-Tac-Toe in PL/pgSQL

A playable Tic-Tac-Toe game implemented as PostgreSQL stored functions.

**Stack:** PostgreSQL, PL/pgSQL

---

## 03 — MongoDB Queries

Queries for a hotel booking database modeled as nested JSON documents.

**Schema:** `hotel → rooms[] → bookings[] → guests[]`

**Tasks covered:**
- Finding reservations by guest and reservation status
- Removing a cancelled booking using `$pull`
- Updating a nested note using `$map` and `$mergeObjects`
- Replacing a facility value across all rooms
- Aggregating booking counts per hotel

**Stack:** MongoDB, Cypher (MQL)

---

## 04 — Neo4j Graph Database

A social network graph modeled after an Instagram-like platform, built in Neo4j.

**Nodes:** `User`, `Photo`  
**Relationships:** `POSTED`, `LIKED`, `COMMENTED`, `FOLLOWS`

**Tasks covered:**
- Updating relationship properties (editing a comment)
- Deleting relationships (unfollowing all users)
- Traversing the graph (photos posted by followed users)
- Aggregating relationship counts (likes on a user's photos)
- Friend-of-friend recommendations (suggest users to follow based on common connections)

**Stack:** Neo4j, Cypher

---

## 05 — Power BI Report

A data visualization report built on the WideWorldImporters DWH dataset.

**Data source:** WideWorldImporters sample database by Microsoft  
**Schema:** Star schema with `FactOrder` and dimension tables for customers, employees, stock items, cities, and dates.

**Stack:** Power BI
