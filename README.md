# Matiks — User Behaviour & Revenue Analysis

## Overview
A data analysis project for a gaming platform. The task: analyse user-level behavioural and revenue data to identify what's working, what's not, and where the opportunities lie - then present it through an interactive dashboard and a short insights report.

Matiks provided a 10,000-user dataset covering signup activity, device and platform usage, session behaviour, subscription tier, and revenue. The goal was to:

* Build an interactive dashboard tracking core usage and revenue metrics, with breakdowns by device, segment, and game mode
* Identify behavioural patterns, early signs of churn, and characteristics of high-value users
* Turn the findings into clear, actionable recommendations for the business

### Tools Used
SQL Server, Power BI, DAX and Power Query

### Repository Contents

| File | Description |
|---|---|
| `Matiks_Dataset.csv` | Raw 10,000-user dataset provided by Matiks |
| `Matiks.sql` | SQL script covering table setup, cohort logic, recency/churn segmentation, high-value user segmentation, and funnel tracking |
| `Matiks.pbix` | Power BI dashboard file |
| `Matiks_Question.md` | Dashboard page-by-page spec derived from the brief |

### Data Model
Data Model

The model is built around a central `Matiks` table holding user demographics, behaviour, and revenue fields, joined 1-to-1 on User_ID to `vw_UserCohorts` (signup cohort and tenure) and `vw_UserRecency` (days since last login and recency segment). A separate `DateTable` connects to `Matiks` in a many-to-one relationship to support time intelligence across the dashboard.

![screenshot of the data model](Image/Data-model.png)

### Assumptions

1. This is a user-level snapshot and an event log. Each row represents one user with lifetime totals; there is no daily active table. This means true DAU/MAU/WAU, which are built from a repeated login table. So, last login recency was used as a proxy.  A user is counted as "active" in a given window if the most recent recorded login falls within it. This also affects churn rate; we can't find a churn rate for periods longer than 30 days.
2. Revenue trend over time cannot be determined because the Total_Revenue_USD represent lifetime revenue per user rather than total revenue recorded at specific points in time; hence, Revenue trend by sign-up month was used to identify the cohort that gave the highest revenue.

### Dashboard

The Power BI dashboard is organised into 5 pages:

1. Overview: KPI cards (Users, Revenue, ARPU, ARPPU, Churn Rate, Conversion Rate), revenue by cohort, signup trend, revenue split by tier
2. Breakdowns:  revenue by device, game mode, game title, subscription tier, and country.
3. Behavioural Patterns: session and duration distributions, sessions-vs-revenue scatter, revenue by rank tier
4. Churn & Retention: recency segment KPIs, days-since-login distribution, churn rate by device/tier/referral source, at-risk high-value user table
5. High-Value Users & Cohorts: top revenue decile profile, frequency-vs-revenue quadrant, revenue by referral source







