FROM postgres:15-alpine

# Set environment variables for Postgres
ENV POSTGRES_USER=postgres
ENV POSTGRES_PASSWORD=1234

COPY create-db.sql /docker-entrypoint-initdb.d/

# Expose PostgreSQL port
EXPOSE 5432

# Default command (already set in postgres:alpine, but explicit here)
CMD ["postgres"]