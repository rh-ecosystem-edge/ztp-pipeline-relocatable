export const EMPTY_VIP = '            '; // 12 characters

export const ADDRESS_POOL_ANNOTATION_KEY = 'metallb.universe.tf/address-pool';
export const ADDRESS_POOL_NAMESPACE = 'metallb';

export const DELAY_BEFORE_RECONCILIATION = 10 * 1000;
export const DELAY_BEFORE_QUERY_RETRY = 5 * 1000; /* ms */
export const MAX_LIVENESS_CHECK_COUNT = 20 * ((60 * 1000) / DELAY_BEFORE_QUERY_RETRY); // max 20 minutes
