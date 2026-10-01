const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST');
    return res.status(405).json({ error: 'Method not allowed' });
  }

  let body = req.body;
  if (typeof body === 'string') {
    try {
      body = JSON.parse(body);
    } catch {
      body = {};
    }
  }

  const email = (body && typeof body.email === 'string' ? body.email : '').trim().toLowerCase();
  if (!EMAIL_RE.test(email)) {
    return res.status(400).json({ error: 'Valid email required' });
  }

  // Account deletion request — verify ownership via the registered email,
  // then remove the account and associated data within 30 days.
  console.log('Pootu delete-account request:', email);

  return res.status(200).json({
    ok: true,
    message: 'Deletion request received. We will process it within 30 days.'
  });
}
