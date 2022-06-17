import React from 'react';

export type SettingsPageContextData = {
  isEdit: boolean;
  setEdit: (v: boolean) => void;

  activeTabKey: number;
  setActiveTabKey: (v: number) => void;

  isCertificateAutomatic: boolean;
  setCertificateAutomatic: (v: boolean) => void;
};

const SettingsPageContext = React.createContext<SettingsPageContextData | undefined>(undefined);

export const SettingsPageContextProvider: React.FC<{
  children: React.ReactNode;
}> = ({ children }) => {
  const [isEdit, setEdit] = React.useState(false);
  const [activeTabKey, setActiveTabKey] = React.useState(0);
  const [isCertificateAutomatic, setCertificateAutomatic] = React.useState(true);

  const value = React.useMemo(
    () => ({
      isEdit,
      setEdit,

      activeTabKey,
      setActiveTabKey,

      isCertificateAutomatic,
      setCertificateAutomatic,
    }),
    [
      activeTabKey,
      setActiveTabKey,
      isCertificateAutomatic,
      setCertificateAutomatic,
      isEdit,
      setEdit,
    ],
  );

  return <SettingsPageContext.Provider value={value}>{children}</SettingsPageContext.Provider>;
};

export const useSettingsPageContext = () => {
  const context = React.useContext(SettingsPageContext);
  if (!context) {
    throw new Error('useSettingsPageContext must be used within K8SSettingsPageContextProvider.');
  }
  return context;
};
