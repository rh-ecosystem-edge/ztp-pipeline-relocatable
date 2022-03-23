import { promisify } from 'util';

export const execPromise = promisify(require('child_process').exec);
