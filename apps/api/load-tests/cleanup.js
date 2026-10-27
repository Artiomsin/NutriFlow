import { deleteUsers, loginExistingUsers } from './lib/users.js';
import {
  loadTestUserCount,
  requireProvisioningPermission,
  requireSafeTarget,
} from './lib/config.js';

const userCount = loadTestUserCount(25);

export const options = { vus: 1, iterations: 1 };

export function setup() {
  requireSafeTarget();
  requireProvisioningPermission();
  return loginExistingUsers(userCount);
}

export default function (users) {
  deleteUsers(users);
}
