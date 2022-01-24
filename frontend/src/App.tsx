import React from "react";
import logo from "./logo.svg";
import "./App.css";

import { getService } from "./resources/service";

function App() {
  React.useEffect(() => {
    const doItAsync = async () => {
      const service = await getService({
        name: "router-internal-default",
        namespace: "openshift-ingress",
      }).promise;
      console.log("--- Service: ", service);
    };

    doItAsync();
  }, []);

  return (
    <div className="App">
      <header className="App-header">
        <img src={logo} className="App-logo" alt="logo" />
        <p>
          Edit <code>src/App.tsx</code> and save to reload.
        </p>
        <a
          className="App-link"
          href="https://reactjs.org"
          target="_blank"
          rel="noopener noreferrer"
        >
          Learn React
        </a>
      </header>
    </div>
  );
}

export default App;
