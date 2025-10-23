SELECT reviewer_id, COUNT(*)
FROM silver.dim_users
GROUP BY reviewer_id
HAVING COUNT(*) <= 0;
