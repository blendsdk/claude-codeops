// HTTP API surface for invoice retrieval and payment capture.
router.get('/invoices/:id', requireSession, async (req, res) => { /* ... */ });
router.post('/invoices/:id/pay', requireSession, async (req, res) => { /* ... */ });
