// jest-dom adds custom jest matchers for asserting on DOM nodes.
// allows you to do things like:
// expect(element).toHaveTextContent(/react/i)
// learn more: https://github.com/testing-library/jest-dom
import '@testing-library/jest-dom';
import replaceAllInserter from 'string.prototype.replaceall';
import fetchMock from 'jest-fetch-mock';
import 'jest-location-mock';

replaceAllInserter.shim();
fetchMock.enableMocks();
global.URL.createObjectURL = jest.fn();
