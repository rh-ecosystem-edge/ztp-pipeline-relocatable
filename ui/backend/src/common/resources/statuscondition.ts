export type StatusCondition = {
  status: string;
  type: string;

  lastTransitionTime: string;
  message: string;
  reason: string;
};

export const getCondition = (
  resource: {
    status?: {
      conditions?: StatusCondition[];
    };
  },
  type: string,
): StatusCondition | undefined =>
  resource?.status?.conditions?.find((c: StatusCondition) => c.type === type);
