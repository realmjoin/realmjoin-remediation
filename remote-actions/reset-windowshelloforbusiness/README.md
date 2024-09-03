# Reset Windows Hello for Business
Delete Windows Hello for Business Container via certutil. Aftwards, user(s) will be prompted to re-enroll WHfB when logging in (username and password required).

Detection script checks first if Windows Hello PIN is configured for local users and how many credentials are available.

## Caution!
Designed for **on-demand execution on single devices**.