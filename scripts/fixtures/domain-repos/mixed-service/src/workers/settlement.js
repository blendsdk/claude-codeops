// Background queue consumer: settles captured payments asynchronously.
queue.process('settle', async (job) => { /* ... */ });
