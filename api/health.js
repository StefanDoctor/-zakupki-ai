export default async function handler(req, res) {
  res.status(200).json({
    ok: true,
    service: "zakupki-ai-api",
    time: new Date().toISOString()
  });
}
