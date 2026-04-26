import { FC, ReactNode, useEffect, useState } from 'react';
import { createPortal } from 'react-dom';

interface PortalProps {
  children: ReactNode;
  containerId?: string;
}

const Portal: FC<PortalProps> = ({ children, containerId = 'portal-root' }) => {
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    let container = document.getElementById(containerId);
    if (!container) {
      container = document.createElement('div');
      container.id = containerId;
      document.body.appendChild(container);
    }
    setMounted(true);
  }, [containerId]);

  return mounted
    ? createPortal(children, document.getElementById(containerId) as HTMLElement)
    : null;
};

export default Portal;
