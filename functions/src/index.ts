// functions/src/index.ts
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import * as logger from "firebase-functions/logger";
import axios from "axios";

const TRANSPORTAPI_APP_ID = defineSecret("TRANSPORTAPI_APP_ID");
const TRANSPORTAPI_APP_KEY = defineSecret("TRANSPORTAPI_APP_KEY");

export const planJourney = onCall(
  { region: "us-central1", secrets: [TRANSPORTAPI_APP_ID, TRANSPORTAPI_APP_KEY] },
  async (request) => {
    logger.info("planJourney called", { hasAuth: !!request.auth, data: request.data });

    const { fromLat, fromLng, toLat, toLng } = (request.data ?? {}) as any;

    const nums = [fromLat, fromLng, toLat, toLng];
    if (nums.some((n) => typeof n !== "number" || Number.isNaN(n))) {
      throw new HttpsError("invalid-argument", "Missing or invalid coordinates");
    }

    const appId = TRANSPORTAPI_APP_ID.value();
    const appKey = TRANSPORTAPI_APP_KEY.value();

    logger.info("secrets loaded", { appIdPresent: !!appId, appKeyPresent: !!appKey });

    if (!appId || !appKey) {
      throw new HttpsError("failed-precondition", "TransportAPI keys not configured");
    }

    const url =
      `https://transportapi.com/v3/uk/public/journey/from/${fromLat},${fromLng}` +
      `/to/${toLat},${toLng}.json`;

    logger.info("calling transportapi", { url });

    try {
      const response = await axios.get(url, {
        params: { app_id: appId, app_key: appKey },
        timeout: 15000,
      });

      logger.info("transportapi success", { status: response.status });
      return response.data;
    } catch (err: any) {
      if (axios.isAxiosError(err)) {
        const details = {
          axiosMessage: err.message,
          axiosCode: err.code,
          status: err.response?.status,
          statusText: err.response?.statusText,
          data: err.response?.data,
        };

        logger.error("transportapi axios error", details);

        throw new HttpsError(
          "internal",
          `TransportAPI failed (${err.response?.status ?? "no-status"})`,
          details,
        );
      }

      logger.error("transportapi unknown error", err);
      throw new HttpsError("internal", "TransportAPI request failed (unknown)", {
        message: String(err),
      });
    }
  }
);