import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  // Simulating 1000 TPS to observe Horizontal Pod Autoscaler (HPA) scaling behavior
  stages: [
    { duration: '1m', target: 100 }, // Ramp-up to 100 users over 1 minute
    { duration: '3m', target: 1000 }, // Ramp-up to 1000 users over 3 minutes
    { duration: '2m', target: 1000 }, // Stay at 1000 users for 2 minutes
    { duration: '1m', target: 0 },    // Ramp-down to 0 users
  ],
};

export default function () {
  const BASE_URL = __ENV.PROD_URL || 'http://localhost:8080';
  
  // Create a random payment ID to bypass idempotency cache and force full DB/Kafka processing
  const randomId = Math.random().toString(36).substring(7);

  const payload = JSON.stringify({
    idempotency_key: randomId,
    amount: Math.floor(Math.random() * 1000) + 1,
    currency: "USD",
    card_token: "tok_visa",
    description: "Load test payment"
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
    timeout: '5s'
  };

  const res = http.post(`${BASE_URL}/v1/payments`, payload, params);

  check(res, {
    'is status 200 or 202': (r) => r.status === 200 || r.status === 202,
    'response time < 2000ms': (r) => r.timings.duration < 2000,
  });

  // Small sleep to pace the requests and avoid overwhelming the K6 runner itself
  sleep(1);
}
