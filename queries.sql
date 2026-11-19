-- OTT Streaming Content Trend Analysis: core SQL aggregations (SQLite dialect)
-- Table: movies(ID, Title, Year, Age, Netflix, Hulu, Prime_Video, Disney_Plus, rt_score)
-- Note: in the notebook, missing Age was filled with 'Unrated' before loading.

CREATE VIEW platform_titles AS
  SELECT ID, Title, Year, Age, rt_score, 'Netflix'     AS platform FROM movies WHERE Netflix = 1
  UNION ALL SELECT ID, Title, Year, Age, rt_score, 'Prime Video' FROM movies WHERE Prime_Video = 1
  UNION ALL SELECT ID, Title, Year, Age, rt_score, 'Hulu'        FROM movies WHERE Hulu = 1
  UNION ALL SELECT ID, Title, Year, Age, rt_score, 'Disney+'     FROM movies WHERE Disney_Plus = 1;

-- Q1: Catalog size, avg rating, % acclaimed per platform
SELECT platform,
       COUNT(*)                                             AS titles,
       ROUND(AVG(rt_score), 1)                              AS avg_rt,
       ROUND(100.0 * SUM(rt_score >= 80) / COUNT(rt_score), 1) AS pct_acclaimed_80plus
FROM platform_titles
GROUP BY platform
ORDER BY titles DESC;

-- Q2: Recency of each catalog
SELECT platform,
       ROUND(100.0 * AVG(Year >= 2010), 1) AS pct_2010_plus,
       ROUND(100.0 * AVG(Year >= 2018), 1) AS pct_2018_plus,
       ROUND(100.0 * AVG(Year <  1990), 1) AS pct_pre_1990
FROM platform_titles
GROUP BY platform
ORDER BY pct_2018_plus DESC;

-- Q3: Age-rating (audience) mix per platform
SELECT platform,
       ROUND(100.0 * SUM(Age IN ('all','7+'))   / COUNT(*), 1) AS pct_family,
       ROUND(100.0 * SUM(Age IN ('13+','16+'))  / COUNT(*), 1) AS pct_teen,
       ROUND(100.0 * SUM(Age = '18+')           / COUNT(*), 1) AS pct_adult,
       ROUND(100.0 * SUM(Age = 'Unrated')       / COUNT(*), 1) AS pct_unrated
FROM platform_titles
GROUP BY platform;

-- Q4: Titles per release year with YoY change (window fn)
WITH yearly AS (
  SELECT platform, Year, COUNT(*) AS titles
  FROM platform_titles WHERE Year BETWEEN 2014 AND 2020
  GROUP BY platform, Year)
SELECT platform, Year, titles,
       titles - LAG(titles) OVER (PARTITION BY platform ORDER BY Year) AS yoy_change
FROM yearly
ORDER BY platform, Year;

-- Q5: Top 5 rated titles per platform (ROW_NUMBER)
SELECT platform, Title, Year, rt_score FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY platform ORDER BY rt_score DESC, Year DESC) AS rn
  FROM platform_titles WHERE rt_score IS NOT NULL)
WHERE rn <= 5
ORDER BY platform, rt_score DESC;

-- Q6: Exclusivity: number of platforms per title
SELECT CASE WHEN n = 1 THEN 'single platform' ELSE n || ' platforms' END AS availability,
       COUNT(*) AS titles,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM movies), 1) AS pct
FROM (SELECT Netflix + Prime_Video + Hulu + Disney_Plus AS n FROM movies)
GROUP BY n ORDER BY n;

-- Q6b: Pairwise platform overlap
SELECT SUM(Netflix AND Prime_Video) AS netflix_prime, SUM(Netflix AND Hulu) AS netflix_hulu,
       SUM(Prime_Video AND Hulu) AS prime_hulu,       SUM(Disney_Plus AND Prime_Video) AS disney_prime
FROM movies;

-- Q7: Avg rating by decade and platform
SELECT (Year/10)*10 AS decade, platform, COUNT(*) AS titles, ROUND(AVG(rt_score),1) AS avg_rt
FROM platform_titles
WHERE Year >= 1980
GROUP BY decade, platform
HAVING COUNT(*) >= 30
ORDER BY decade, platform;

