import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  // Smoke tests should be very quick, 1 virtual user for 1 iteration
  vus: 1,
  iterations: 1,
  // Ensure the test times out if the API hangs
  duration: '10s',
};

export default function () {
  // Look for an environment variable injected by CI, otherwise fallback to localhost
  const BASE_URL = __ENV.STAGING_URL || 'http://localhost:8080';
  
  // Create a realistic dummy payload for the payment API
  const payload = JSON.stringify({
    amount: 100,
    currency: "USD",
    card_token: "tok_visa",
    description: "Smoke test payment"
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
      // In a real staging environment, we would inject a valid JWT token from Secrets Manager here.
      // 'Authorization': `Bearer ${__ENV.JWT_TOKEN}`
    },
    timeout: '5s'
  };

  // Send a POST request to the payment creation endpoint
  const res = http.post(`${BASE_URL}/v1/payments`, payload, params);

  // Verify the API returns a 200 OK or 202 ACCEPTED (Async processing)
  check(res, {
    'is status 200 or 202': (r) => r.status === 200 || r.status === 202,
    'response time < 2000ms': (r) => r.timings.duration < 2000,
  });

  sleep(1);
}
