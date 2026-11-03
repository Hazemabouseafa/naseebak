<x-filament-panels::page>
    <form wire:submit="save" class="space-y-6" dir="rtl">
        {{ $this->form }}
        <div>
            <x-filament::button type="submit" color="primary">
                تأكيد وتفعيل بوابة الدفع المختارة
            </x-filament::button>
        </div>
    </form>
</x-filament-panels::page>
