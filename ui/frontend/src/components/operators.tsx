import React from 'react';

import { ClusterOperator, getCondition } from '../copy-backend-common';
import { getClusterOperators } from '../resources/clusteroperator';

import { CLUSTER_OPERATOR_POLLING_INTERVAL, MONITORED_CLUSTER_OPERATORS } from './constants';
import { delay } from './utils';

export const useOperatorsReconciling = (): ClusterOperator[] | undefined => {
  const [operatorsReconciling, setOperatorsReconciling] = React.useState<ClusterOperator[]>();
  const [pollingTimmer, setPollingTimmer] = React.useState<number>(0);

  React.useEffect(() => {
    let stopIt = false;

    const doItAsync = async () => {
      const operators = await getClusterOperators().promise;

      const filteredOperators = operators.filter(
        (op) =>
          MONITORED_CLUSTER_OPERATORS.includes(op.metadata.name as string) &&
          (getCondition(op, 'Progressing')?.status === 'True' ||
            getCondition(op, 'Degraded')?.status === 'True' ||
            getCondition(op, 'Available')?.status === 'False'),
      );

      if (!stopIt) {
        setOperatorsReconciling(
          filteredOperators.sort(
            (op1, op2) => op1.metadata.name?.localeCompare(op2.metadata.name as string) || -1,
          ),
        );

        await delay(CLUSTER_OPERATOR_POLLING_INTERVAL);

        if (!stopIt) {
          setPollingTimmer(pollingTimmer + 1);
        }
      }
    };

    doItAsync();

    return () => {
      stopIt = true;
    };
  }, [pollingTimmer]);

  return operatorsReconciling;
};
