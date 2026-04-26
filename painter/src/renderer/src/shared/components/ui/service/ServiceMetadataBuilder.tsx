import { FC } from 'react';
import { Plus, Trash2, Type, List, Asterisk } from 'lucide-react';
import { cn } from '../../../lib/utils';
import Input from '../input/Input';

export interface MetadataItem {
  key: string;
  type: 'string' | 'array';
  value: string;
  required?: boolean;
}

interface ServiceMetadataBuilderProps {
  metadata: MetadataItem[];
  onChange: (metadata: MetadataItem[]) => void;
  className?: string;
  definitionOnly?: boolean;
}

const ServiceMetadataBuilder: FC<ServiceMetadataBuilderProps> = ({
  metadata,
  onChange,
  className,
  definitionOnly = false,
}) => {
  const addItem = () => {
    onChange([...metadata, { key: '', type: 'string', value: '', required: true }]);
  };

  const removeItem = (index: number) => {
    onChange(metadata.filter((_, i) => i !== index));
  };

  const updateItem = (index: number, updates: Partial<MetadataItem>) => {
    onChange(metadata.map((item, i) => (i === index ? { ...item, ...updates } : item)));
  };

  return (
    <div className={cn('space-y-4', className)}>
      <div className="flex items-center justify-between">
        <label className="text-[12px] font-bold uppercase tracking-wider text-muted-foreground/70">
          Metadata Fields
        </label>
        <button
          onClick={addItem}
          className="text-xs font-bold uppercase tracking-wider text-primary hover:text-primary/70 transition-colors flex items-center gap-1.5"
        >
          <Plus className="w-3 h-3" />
          Add Field
        </button>
      </div>

      <div className="space-y-3">
        {metadata.length === 0 && (
          <div className="py-8 text-center border border-dashed border-border/50 rounded-2xl bg-muted/5">
            <span className="text-xs font-bold text-muted-foreground/40 uppercase tracking-wider">
              No custom fields added
            </span>
          </div>
        )}
        {metadata.map((item, index) => (
          <div
            key={index}
            className="flex gap-3 items-start animate-in fade-in slide-in-from-top-1 duration-300"
          >
            <div className="flex-1 space-y-2">
              <div className="flex gap-2">
                <Input
                  placeholder="Field label (e.g. profile_url)"
                  value={item.key}
                  onChange={(e) => updateItem(index, { key: e.target.value })}
                  className="bg-input-background border-border rounded-xl h-11"
                />
                <div className="flex items-center bg-muted/10 rounded-xl px-1 border border-border h-11">
                  <button
                    onClick={() => updateItem(index, { type: 'string' })}
                    className={cn(
                      'p-1.5 rounded-lg transition-all',
                      item.type === 'string'
                        ? 'bg-primary text-white shadow-lg shadow-primary/20'
                        : 'text-muted-foreground/40 hover:text-muted-foreground',
                    )}
                    title="String"
                  >
                    <Type className="w-3.5 h-3.5" />
                  </button>
                  <button
                    onClick={() => updateItem(index, { type: 'array' })}
                    className={cn(
                      'p-1.5 rounded-lg transition-all',
                      item.type === 'array'
                        ? 'bg-primary text-white shadow-lg shadow-primary/20'
                        : 'text-muted-foreground/40 hover:text-muted-foreground',
                    )}
                    title="Array of Strings"
                  >
                    <List className="w-3.5 h-3.5" />
                  </button>
                </div>

                <button
                  onClick={() => updateItem(index, { required: !item.required })}
                  className={cn(
                    'flex items-center gap-2 px-3 rounded-xl border transition-all h-11',
                    item.required
                      ? 'bg-red-500/10 border-red-500/50 text-red-500 shadow-lg shadow-red-500/5'
                      : 'bg-muted/10 border-border text-muted-foreground/40 hover:text-muted-foreground',
                  )}
                  title={item.required ? 'Required' : 'Optional'}
                >
                  <Asterisk className={cn('w-3.5 h-3.5', item.required ? 'animate-pulse' : '')} />
                  <span className="text-xs font-bold uppercase tracking-wider hidden sm:inline">
                    {item.required ? 'Required' : 'Optional'}
                  </span>
                </button>
              </div>
              {!definitionOnly && (
                <Input
                  placeholder={
                    item.type === 'array'
                      ? 'Values (comma separated for array)...'
                      : 'Value (e.g. https://facebook.com/me)'
                  }
                  value={item.value}
                  onChange={(e) => updateItem(index, { value: e.target.value })}
                  className="bg-input-background border-border rounded-xl h-11"
                />
              )}
            </div>
            <button
              onClick={() => removeItem(index)}
              className="mt-2 p-1.5 rounded-lg text-muted-foreground/20 hover:text-destructive hover:bg-destructive/10 transition-all"
            >
              <Trash2 className="w-4 h-4" />
            </button>
          </div>
        ))}
      </div>
    </div>
  );
};

export default ServiceMetadataBuilder;
