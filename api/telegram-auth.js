import crypto from "crypto";

const MAX_AUTH_AGE_SECONDS = 24 * 60 * 60;

function parseInitData(initData) {
  const params = new URLSearchParams(initData);

  const hash = params.get("hash");

  if (!hash) {
    throw new Error("Missing Telegram hash");
  }

  params.delete("hash");

  const entries = Array.from(params.entries())
    .sort(([a], [b]) => a.localeCompare(b));

  const dataCheckString = entries
    .map(([key, value]) => `${key}=${value}`)
    .join("\n");

  return {
    params,
    hash,
    dataCheckString
  };
}

function verifyTelegramInitData(initData, botToken) {
  const {
    params,
    hash,
    dataCheckString
  } = parseInitData(initData);

  const authDateRaw = params.get("auth_date");
  const authDate = Number(authDateRaw);

  if (!Number.isInteger(authDate)) {
    throw new Error("Invalid auth_date");
  }

  const now = Math.floor(Date.now() / 1000);

  if (authDate > now + 60) {
    throw new Error("Telegram auth_date is in the future");
  }

  if (now - authDate > MAX_AUTH_AGE_SECONDS) {
    throw new Error("Telegram initData has expired");
  }

  const secretKey = crypto
    .createHmac("sha256", "WebAppData")
    .update(botToken)
    .digest();

  const calculatedHash = crypto
    .createHmac("sha256", secretKey)
    .update(dataCheckString)
    .digest("hex");

  const providedBuffer = Buffer.from(hash, "hex");
  const calculatedBuffer = Buffer.from(calculatedHash, "hex");

  if (
    providedBuffer.length !== calculatedBuffer.length ||
    !crypto.timingSafeEqual(providedBuffer, calculatedBuffer)
  ) {
    throw new Error("Invalid Telegram signature");
  }

  const userRaw = params.get("user");

  if (!userRaw) {
    throw new Error("Telegram user is missing");
  }

  let user;

  try {
    user = JSON.parse(userRaw);
  } catch {
    throw new Error("Invalid Telegram user JSON");
  }

  if (!user || !user.id) {
    throw new Error("Invalid Telegram user");
  }

  return user;
}

export default async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({
      ok: false,
      error: "Method not allowed"
    });
  }

  try {
    const botToken = process.env.TELEGRAM_BOT_TOKEN;

    if (!botToken) {
      return res.status(500).json({
        ok: false,
        error: "Telegram bot token is not configured"
      });
    }

    const body = req.body || {};

    const initData =
      typeof body.initData === "string"
        ? body.initData
        : "";

    if (!initData) {
      return res.status(400).json({
        ok: false,
        error: "initData is required"
      });
    }

    const telegramUser = verifyTelegramInitData(
      initData,
      botToken
    );

    return res.status(200).json({
      ok: true,
      user: {
        id: telegramUser.id,
        first_name: telegramUser.first_name || "",
        last_name: telegramUser.last_name || "",
        username: telegramUser.username || "",
        language_code: telegramUser.language_code || "",
        is_premium: Boolean(telegramUser.is_premium)
      }
    });
  } catch (error) {
    return res.status(401).json({
      ok: false,
      error: error instanceof Error
        ? error.message
        : "Telegram authentication failed"
    });
  }
}
