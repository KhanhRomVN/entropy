import { motion, AnimatePresence } from 'framer-motion';
import { DrawerProps } from './Drawer.types';
import { getDrawerVariants, getDrawerPosition, overlayVariants } from './Drawer.utils';
import { cn } from '../../../../shared/lib/utils';
import { X } from 'lucide-react';

const Drawer: React.FC<DrawerProps> = ({
  isOpen,
  onClose,
  direction = 'right',
  children,
  className = '',
  overlayClassName = '',
  animationType = 'slide',
  closeOnOverlayClick = true,
  width,
  height,
  showOverlay = true,
  title,
  subtitle,
  headerActions,
  footerActions,
  enableBlur = true,
  showCloseButton = true,
  overlayOpacity = 0.5,
}) => {
  const drawerVariants = getDrawerVariants(direction, animationType);
  const drawerPosition = getDrawerPosition(direction, width, height);

  return (
    <AnimatePresence>
      {isOpen && (
        <>
          {/* Overlay */}
          {showOverlay && (
            <motion.div
              initial="hidden"
              animate="visible"
              exit="hidden"
              variants={overlayVariants}
              transition={{ duration: 0.3 }}
              onClick={closeOnOverlayClick ? onClose : undefined}
              className={cn(
                'fixed inset-0 z-[999]',
                enableBlur && 'backdrop-blur-sm',
                overlayClassName,
              )}
              style={{ backgroundColor: `rgba(0, 0, 0, ${overlayOpacity})` }}
            />
          )}

          {/* Drawer */}
          <motion.div
            initial="hidden"
            animate="visible"
            exit="hidden"
            variants={drawerVariants}
            transition={{ duration: 0.3, ease: 'easeInOut' }}
            style={drawerPosition}
            className={cn(
              'z-[1000] flex flex-col bg-card/80 backdrop-blur-2xl border-border shadow-2xl',
              direction === 'right'
                ? 'border-l'
                : direction === 'left'
                  ? 'border-r'
                  : direction === 'top'
                    ? 'border-b'
                    : 'border-t',
              className,
            )}
          >
            {/* Header */}
            {(title || subtitle || showCloseButton || headerActions) && (
              <div className="flex items-center justify-between p-4 border-b border-border shrink-0">
                <div className="flex flex-col gap-1 overflow-hidden">
                  {title && (
                    <h2 className="text-lg font-bold tracking-tight text-foreground truncate">
                      {title}
                    </h2>
                  )}
                  {subtitle && <p className="text-xs text-muted-foreground truncate">{subtitle}</p>}
                </div>
                <div className="flex items-center gap-2">
                  {headerActions}
                  {showCloseButton && (
                    <button
                      onClick={onClose}
                      className="p-2 text-muted-foreground hover:text-red-500 hover:bg-red-500/10 rounded-xl transition-all active:scale-95"
                    >
                      <X className="w-5 h-5" />
                    </button>
                  )}
                </div>
              </div>
            )}

            {/* Content */}
            <div className="flex-1 overflow-y-auto custom-scrollbar">{children}</div>

            {/* Footer */}
            {footerActions && (
              <div className="p-4 border-t border-border shrink-0">{footerActions}</div>
            )}
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
};

export default Drawer;
